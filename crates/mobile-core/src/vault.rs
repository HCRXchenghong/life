#![forbid(unsafe_code)]

use std::fs::{self, File, OpenOptions};
use std::io::{ErrorKind, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Nonce};
use hkdf::Hkdf;
use serde::{Deserialize, Serialize};
use sha2_11::Sha256;
use uuid::Uuid;
use zeroize::Zeroize;

const VAULT_MAGIC: &[u8; 8] = b"DLVLT001";
const VAULT_NONCE_BYTES: usize = 12;
const VAULT_MAX_BYTES: u64 = 1024 * 1024;
const KEY_BYTES: usize = 32;
const RECOVERY_SALT_BYTES: usize = 32;
const RECOVERY_NONCE_BYTES: usize = 12;
const CONTENT_KEY_VERSION: u32 = 1;

static VAULT_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContentKeyStatus {
    Missing,
    PendingRecoveryConfirmation,
    Ready,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContentKeyInitialization {
    pub device_id: String,
    pub key_version: u32,
    pub recovery_key: Vec<u8>,
    pub recovery_salt: Vec<u8>,
    pub recovery_nonce: Vec<u8>,
    pub recovery_ciphertext: Vec<u8>,
}

#[derive(Debug, Serialize, Deserialize)]
struct VaultPlaintext {
    format_version: u32,
    account_id: String,
    device_id: String,
    content_key: Option<ContentKeyRecord>,
}

#[derive(Debug, Serialize, Deserialize)]
struct ContentKeyRecord {
    key_version: u32,
    cmk: Vec<u8>,
    recovery_salt: Vec<u8>,
    recovery_nonce: Vec<u8>,
    recovery_ciphertext: Vec<u8>,
    pending_recovery_key: Option<Vec<u8>>,
}

impl Drop for ContentKeyRecord {
    fn drop(&mut self) {
        self.cmk.zeroize();
        if let Some(key) = self.pending_recovery_key.as_mut() {
            key.zeroize();
        }
    }
}

pub fn generate_device_vault_key() -> Result<Vec<u8>, String> {
    let mut key = vec![0_u8; KEY_BYTES];
    getrandom::fill(&mut key).map_err(|_| "secure random generation failed".to_owned())?;
    Ok(key)
}

pub fn content_key_status(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
) -> Result<ContentKeyStatus, String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let path = validated_vault_path(vault_path)?;
        let Some(vault) = read_vault(&path, &account_id, device_vault_key)? else {
            return Ok(ContentKeyStatus::Missing);
        };
        Ok(match vault.content_key {
            None => ContentKeyStatus::Missing,
            Some(ref record) if record.pending_recovery_key.is_some() => {
                ContentKeyStatus::PendingRecoveryConfirmation
            }
            Some(_) => ContentKeyStatus::Ready,
        })
    })
}

pub fn initialize_content_key(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
) -> Result<ContentKeyInitialization, String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let path = validated_vault_path(vault_path)?;
        let mut vault =
            read_vault(&path, &account_id, device_vault_key)?.unwrap_or_else(|| VaultPlaintext {
                format_version: 1,
                account_id: account_id.clone(),
                device_id: Uuid::new_v4().to_string(),
                content_key: None,
            });

        if let Some(record) = vault.content_key.as_ref() {
            return initialization_from_pending(&vault.device_id, record);
        }

        let mut cmk = vec![0_u8; KEY_BYTES];
        let mut recovery_key = vec![0_u8; KEY_BYTES];
        let mut recovery_salt = vec![0_u8; RECOVERY_SALT_BYTES];
        let mut recovery_nonce = vec![0_u8; RECOVERY_NONCE_BYTES];
        getrandom::fill(&mut cmk).map_err(|_| "secure random generation failed".to_owned())?;
        getrandom::fill(&mut recovery_key)
            .map_err(|_| "secure random generation failed".to_owned())?;
        getrandom::fill(&mut recovery_salt)
            .map_err(|_| "secure random generation failed".to_owned())?;
        getrandom::fill(&mut recovery_nonce)
            .map_err(|_| "secure random generation failed".to_owned())?;

        let recovery_ciphertext = wrap_content_key(
            &account_id,
            CONTENT_KEY_VERSION,
            &cmk,
            &recovery_key,
            &recovery_salt,
            &recovery_nonce,
        )?;
        vault.content_key = Some(ContentKeyRecord {
            key_version: CONTENT_KEY_VERSION,
            cmk,
            recovery_salt: recovery_salt.clone(),
            recovery_nonce: recovery_nonce.clone(),
            recovery_ciphertext: recovery_ciphertext.clone(),
            pending_recovery_key: Some(recovery_key.clone()),
        });
        write_vault(&path, &account_id, device_vault_key, &vault)?;
        Ok(ContentKeyInitialization {
            device_id: vault.device_id,
            key_version: CONTENT_KEY_VERSION,
            recovery_key,
            recovery_salt,
            recovery_nonce,
            recovery_ciphertext,
        })
    })
}

pub fn acknowledge_recovery_key_saved(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
) -> Result<(), String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let path = validated_vault_path(vault_path)?;
        let mut vault = read_vault(&path, &account_id, device_vault_key)?
            .ok_or_else(|| "content key is not initialized".to_owned())?;
        let record = vault
            .content_key
            .as_mut()
            .ok_or_else(|| "content key is not initialized".to_owned())?;
        let mut pending = record
            .pending_recovery_key
            .take()
            .ok_or_else(|| "recovery key is already acknowledged".to_owned())?;
        pending.zeroize();
        write_vault(&path, &account_id, device_vault_key, &vault)
    })
}

pub fn discard_pending_content_key(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
) -> Result<(), String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let path = validated_vault_path(vault_path)?;
        let Some(mut vault) = read_vault(&path, &account_id, device_vault_key)? else {
            return Ok(());
        };
        match vault.content_key.as_ref() {
            Some(record) if record.pending_recovery_key.is_some() => {
                vault.content_key = None;
                write_vault(&path, &account_id, device_vault_key, &vault)
            }
            Some(_) => Err("confirmed content key cannot be discarded".to_owned()),
            None => Ok(()),
        }
    })
}

fn initialization_from_pending(
    device_id: &str,
    record: &ContentKeyRecord,
) -> Result<ContentKeyInitialization, String> {
    let recovery_key = record
        .pending_recovery_key
        .clone()
        .ok_or_else(|| "content key is already initialized".to_owned())?;
    Ok(ContentKeyInitialization {
        device_id: device_id.to_owned(),
        key_version: record.key_version,
        recovery_key,
        recovery_salt: record.recovery_salt.clone(),
        recovery_nonce: record.recovery_nonce.clone(),
        recovery_ciphertext: record.recovery_ciphertext.clone(),
    })
}

fn wrap_content_key(
    account_id: &str,
    key_version: u32,
    cmk: &[u8],
    recovery_key: &[u8],
    salt: &[u8],
    nonce: &[u8],
) -> Result<Vec<u8>, String> {
    let hkdf = Hkdf::<Sha256>::new(Some(salt), recovery_key);
    let mut kek = [0_u8; KEY_BYTES];
    let info = format!("daylink-recovery-kek-v1\0{account_id}\0{key_version}");
    hkdf.expand(info.as_bytes(), &mut kek)
        .map_err(|_| "recovery key derivation failed".to_owned())?;
    let cipher =
        Aes256Gcm::new_from_slice(&kek).map_err(|_| "recovery key derivation failed".to_owned())?;
    let aad = format!("daylink-recovery-envelope-v1\0{account_id}\0{key_version}");
    let nonce = Nonce::try_from(nonce).map_err(|_| "recovery nonce is invalid".to_owned())?;
    let result = cipher
        .encrypt(
            &nonce,
            Payload {
                msg: cmk,
                aad: aad.as_bytes(),
            },
        )
        .map_err(|_| "content key wrapping failed".to_owned());
    kek.zeroize();
    result
}

fn read_vault(
    path: &Path,
    account_id: &str,
    device_vault_key: &[u8],
) -> Result<Option<VaultPlaintext>, String> {
    validate_device_key(device_vault_key)?;
    reject_symlink(path)?;
    let mut file = match File::open(path) {
        Ok(file) => file,
        Err(error) if error.kind() == ErrorKind::NotFound => return Ok(None),
        Err(_) => return Err("vault could not be opened".to_owned()),
    };
    let metadata = file
        .metadata()
        .map_err(|_| "vault metadata is unavailable".to_owned())?;
    if metadata.len() > VAULT_MAX_BYTES || metadata.len() < (VAULT_MAGIC.len() + 13) as u64 {
        return Err("vault file is invalid".to_owned());
    }
    let capacity = usize::try_from(metadata.len())
        .map_err(|_| "vault file is too large for this device".to_owned())?;
    let mut bytes = Vec::with_capacity(capacity);
    file.read_to_end(&mut bytes)
        .map_err(|_| "vault could not be read".to_owned())?;
    if bytes.get(..VAULT_MAGIC.len()) != Some(VAULT_MAGIC.as_slice()) {
        return Err("vault file is invalid".to_owned());
    }
    let nonce_start = VAULT_MAGIC.len();
    let ciphertext_start = nonce_start + VAULT_NONCE_BYTES;
    let nonce = bytes
        .get(nonce_start..ciphertext_start)
        .ok_or_else(|| "vault file is invalid".to_owned())?;
    let ciphertext = bytes
        .get(ciphertext_start..)
        .ok_or_else(|| "vault file is invalid".to_owned())?;
    let cipher = Aes256Gcm::new_from_slice(device_vault_key)
        .map_err(|_| "device vault key is invalid".to_owned())?;
    let aad = vault_aad(account_id);
    let nonce = Nonce::try_from(nonce).map_err(|_| "vault file is invalid".to_owned())?;
    let mut plaintext = cipher
        .decrypt(
            &nonce,
            Payload {
                msg: ciphertext,
                aad: &aad,
            },
        )
        .map_err(|_| "vault could not be unlocked".to_owned())?;
    let decoded: VaultPlaintext =
        serde_json::from_slice(&plaintext).map_err(|_| "vault contents are invalid".to_owned())?;
    plaintext.zeroize();
    if decoded.format_version != 1 || decoded.account_id != account_id {
        return Err("vault account binding is invalid".to_owned());
    }
    if Uuid::parse_str(&decoded.device_id).is_err() {
        return Err("vault device binding is invalid".to_owned());
    }
    validate_record(decoded.content_key.as_ref())?;
    Ok(Some(decoded))
}

fn write_vault(
    path: &Path,
    account_id: &str,
    device_vault_key: &[u8],
    vault: &VaultPlaintext,
) -> Result<(), String> {
    validate_device_key(device_vault_key)?;
    validate_record(vault.content_key.as_ref())?;
    let parent = path
        .parent()
        .ok_or_else(|| "vault path is invalid".to_owned())?;
    fs::create_dir_all(parent).map_err(|_| "vault directory could not be created".to_owned())?;
    set_owner_only_directory_permissions(parent)?;
    reject_symlink(path)?;

    let mut plaintext =
        serde_json::to_vec(vault).map_err(|_| "vault contents could not be encoded".to_owned())?;
    let mut nonce = [0_u8; VAULT_NONCE_BYTES];
    getrandom::fill(&mut nonce).map_err(|_| "secure random generation failed".to_owned())?;
    let cipher = Aes256Gcm::new_from_slice(device_vault_key)
        .map_err(|_| "device vault key is invalid".to_owned())?;
    let aad = vault_aad(account_id);
    let nonce_array =
        Nonce::try_from(nonce.as_slice()).map_err(|_| "vault nonce is invalid".to_owned())?;
    let ciphertext = cipher
        .encrypt(
            &nonce_array,
            Payload {
                msg: &plaintext,
                aad: &aad,
            },
        )
        .map_err(|_| "vault encryption failed".to_owned())?;
    plaintext.zeroize();

    let temp_path = temporary_path(path);
    let write_result = (|| {
        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        set_owner_only_file_options(&mut options);
        let mut file = options
            .open(&temp_path)
            .map_err(|_| "vault temporary file could not be created".to_owned())?;
        file.write_all(VAULT_MAGIC)
            .and_then(|()| file.write_all(&nonce))
            .and_then(|()| file.write_all(&ciphertext))
            .and_then(|()| file.sync_all())
            .map_err(|_| "vault could not be written".to_owned())?;
        fs::rename(&temp_path, path).map_err(|_| "vault could not be committed".to_owned())?;
        sync_parent_directory(parent);
        Ok(())
    })();
    if write_result.is_err() {
        let _ = fs::remove_file(&temp_path);
    }
    write_result
}

fn validate_record(record: Option<&ContentKeyRecord>) -> Result<(), String> {
    let Some(record) = record else {
        return Ok(());
    };
    if record.key_version != CONTENT_KEY_VERSION
        || record.cmk.len() != KEY_BYTES
        || record.recovery_salt.len() != RECOVERY_SALT_BYTES
        || record.recovery_nonce.len() != RECOVERY_NONCE_BYTES
        || record.recovery_ciphertext.len() != KEY_BYTES + 16
        || record
            .pending_recovery_key
            .as_ref()
            .is_some_and(|key| key.len() != KEY_BYTES)
    {
        return Err("vault content key record is invalid".to_owned());
    }
    Ok(())
}

fn canonical_account_id(value: &str) -> Result<String, String> {
    let parsed = Uuid::parse_str(value).map_err(|_| "account ID is invalid".to_owned())?;
    let canonical = parsed.hyphenated().to_string();
    if value.to_ascii_lowercase() != canonical {
        return Err("account ID is not canonical".to_owned());
    }
    Ok(canonical)
}

fn validated_vault_path(value: &str) -> Result<PathBuf, String> {
    let path = PathBuf::from(value);
    if !path.is_absolute() || path.file_name().and_then(|name| name.to_str()) != Some("vault.db") {
        return Err("vault path is invalid".to_owned());
    }
    Ok(path)
}

fn validate_device_key(key: &[u8]) -> Result<(), String> {
    if key.len() != KEY_BYTES {
        return Err("device vault key is invalid".to_owned());
    }
    Ok(())
}

fn vault_aad(account_id: &str) -> Vec<u8> {
    format!("daylink-vault-v1\0{account_id}").into_bytes()
}

fn temporary_path(path: &Path) -> PathBuf {
    let suffix = Uuid::new_v4();
    path.with_file_name(format!("vault.db.tmp-{suffix}"))
}

fn reject_symlink(path: &Path) -> Result<(), String> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => {
            Err("vault path is not a regular file".to_owned())
        }
        Ok(metadata) if !metadata.is_file() => Err("vault path is not a regular file".to_owned()),
        Ok(_) => Ok(()),
        Err(ref error) if error.kind() == ErrorKind::NotFound => Ok(()),
        Err(_) => Err("vault metadata is unavailable".to_owned()),
    }
}

fn with_vault_lock<T>(operation: impl FnOnce() -> Result<T, String>) -> Result<T, String> {
    let guard = VAULT_LOCK
        .get_or_init(|| Mutex::new(()))
        .lock()
        .map_err(|_| "vault lock is unavailable".to_owned())?;
    let result = operation();
    drop(guard);
    result
}

#[cfg(unix)]
fn set_owner_only_file_options(options: &mut OpenOptions) {
    use std::os::unix::fs::OpenOptionsExt;
    options.mode(0o600);
}

#[cfg(not(unix))]
fn set_owner_only_file_options(_options: &mut OpenOptions) {}

#[cfg(unix)]
fn set_owner_only_directory_permissions(path: &Path) -> Result<(), String> {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(path, fs::Permissions::from_mode(0o700))
        .map_err(|_| "vault directory permissions could not be secured".to_owned())
}

#[cfg(not(unix))]
fn set_owner_only_directory_permissions(_path: &Path) -> Result<(), String> {
    Ok(())
}

#[cfg(unix)]
fn sync_parent_directory(path: &Path) {
    if let Ok(directory) = File::open(path) {
        let _ = directory.sync_all();
    }
}

#[cfg(not(unix))]
fn sync_parent_directory(_path: &Path) {}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_path(label: &str) -> PathBuf {
        std::env::temp_dir()
            .join(format!("daylink-vault-{label}-{}", Uuid::new_v4()))
            .join("vault.db")
    }

    #[test]
    fn initializes_idempotently_and_never_writes_plaintext_keys() {
        let path = test_path("initialize");
        let account = "8f2e0a0d-574b-4e53-bf82-1ec9c9bc2521";
        let device_key = generate_device_vault_key().expect("device key");
        let first = initialize_content_key(path.to_str().expect("path"), account, &device_key)
            .expect("initialize");
        let second = initialize_content_key(path.to_str().expect("path"), account, &device_key)
            .expect("resume pending");
        assert_eq!(first, second);
        assert_eq!(first.recovery_ciphertext.len(), 48);
        assert_eq!(
            content_key_status(path.to_str().expect("path"), account, &device_key).expect("status"),
            ContentKeyStatus::PendingRecoveryConfirmation
        );
        let bytes = fs::read(&path).expect("read encrypted vault");
        assert!(
            !bytes
                .windows(first.recovery_key.len())
                .any(|part| part == first.recovery_key)
        );
        assert!(
            !bytes
                .windows(first.recovery_ciphertext.len())
                .any(|part| part == first.recovery_ciphertext)
        );
        let _ = fs::remove_dir_all(path.parent().expect("parent"));
    }

    #[test]
    fn acknowledgement_removes_recovery_key_and_wrong_device_key_is_rejected() {
        let path = test_path("acknowledge");
        let account = "8f2e0a0d-574b-4e53-bf82-1ec9c9bc2521";
        let device_key = generate_device_vault_key().expect("device key");
        let wrong_key = generate_device_vault_key().expect("wrong key");
        initialize_content_key(path.to_str().expect("path"), account, &device_key)
            .expect("initialize");
        assert!(content_key_status(path.to_str().expect("path"), account, &wrong_key).is_err());
        acknowledge_recovery_key_saved(path.to_str().expect("path"), account, &device_key)
            .expect("acknowledge");
        assert_eq!(
            content_key_status(path.to_str().expect("path"), account, &device_key).expect("status"),
            ContentKeyStatus::Ready
        );
        assert!(
            initialize_content_key(path.to_str().expect("path"), account, &device_key).is_err()
        );
        assert!(
            discard_pending_content_key(path.to_str().expect("path"), account, &device_key)
                .is_err()
        );
        let _ = fs::remove_dir_all(path.parent().expect("parent"));
    }

    #[test]
    fn pending_initialization_can_be_discarded_after_server_conflict() {
        let path = test_path("discard");
        let account = "8f2e0a0d-574b-4e53-bf82-1ec9c9bc2521";
        let device_key = generate_device_vault_key().expect("device key");
        initialize_content_key(path.to_str().expect("path"), account, &device_key)
            .expect("initialize");
        discard_pending_content_key(path.to_str().expect("path"), account, &device_key)
            .expect("discard");
        assert_eq!(
            content_key_status(path.to_str().expect("path"), account, &device_key).expect("status"),
            ContentKeyStatus::Missing
        );
        let _ = fs::remove_dir_all(path.parent().expect("parent"));
    }
}
