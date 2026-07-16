#![forbid(unsafe_code)]

use std::fmt;
use std::fs::{self, File, OpenOptions};
use std::io::{ErrorKind, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Nonce};
use curve25519_dalek::constants::X25519_BASEPOINT;
use curve25519_dalek::montgomery::MontgomeryPoint;
use hkdf::Hkdf;
use serde::{Deserialize, Serialize};
use sha2_11::{Digest, Sha256};
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;
use zeroize::{Zeroize, Zeroizing};

const VAULT_MAGIC: &[u8; 8] = b"DLVLT001";
const VAULT_NONCE_BYTES: usize = 12;
const VAULT_MAX_BYTES: u64 = 1024 * 1024;
const KEY_BYTES: usize = 32;
const RECOVERY_SALT_BYTES: usize = 32;
const RECOVERY_NONCE_BYTES: usize = 12;
const CONTENT_KEY_VERSION: u32 = 1;
const DEVICE_APPROVAL_PUBLIC_KEY_BYTES: usize = 32;
const DEVICE_APPROVAL_NONCE_BYTES: usize = 12;
const DEVICE_APPROVAL_MAX_PENDING: usize = 8;
const DEVICE_APPROVAL_MAX_LIFETIME_MS: u64 = 15 * 60 * 1000;

static VAULT_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContentKeyStatus {
    Missing,
    PendingRecoveryConfirmation,
    Ready,
}

#[derive(Clone, PartialEq, Eq)]
pub struct ContentKeyInitialization {
    pub device_id: String,
    pub key_version: u32,
    pub recovery_key: Vec<u8>,
    pub recovery_salt: Vec<u8>,
    pub recovery_nonce: Vec<u8>,
    pub recovery_ciphertext: Vec<u8>,
}

#[derive(Clone, PartialEq, Eq)]
pub struct DeviceApprovalRequestKey {
    pub public_key: Vec<u8>,
    pub verification_code: String,
}

impl fmt::Debug for DeviceApprovalRequestKey {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("DeviceApprovalRequestKey")
            .field("public_key_bytes", &self.public_key.len())
            .field("verification_code", &self.verification_code)
            .finish()
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct DeviceApprovalPackage {
    pub approver_public_key: Vec<u8>,
    pub nonce: Vec<u8>,
    pub ciphertext: Vec<u8>,
    pub key_version: u32,
    pub verification_code: String,
}

impl fmt::Debug for DeviceApprovalPackage {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("DeviceApprovalPackage")
            .field("approver_public_key_bytes", &self.approver_public_key.len())
            .field("nonce_bytes", &self.nonce.len())
            .field("ciphertext_bytes", &self.ciphertext.len())
            .field("key_version", &self.key_version)
            .field("verification_code", &self.verification_code)
            .finish()
    }
}

impl fmt::Debug for ContentKeyInitialization {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ContentKeyInitialization")
            .field("device_id", &self.device_id)
            .field("key_version", &self.key_version)
            .field("recovery_key", &"<redacted>")
            .field("recovery_salt_bytes", &self.recovery_salt.len())
            .field("recovery_nonce_bytes", &self.recovery_nonce.len())
            .field("recovery_ciphertext_bytes", &self.recovery_ciphertext.len())
            .finish()
    }
}

#[derive(Serialize, Deserialize)]
struct VaultPlaintext {
    format_version: u32,
    account_id: String,
    device_id: String,
    content_key: Option<ContentKeyRecord>,
    #[serde(default)]
    pending_device_approvals: Vec<PendingDeviceApprovalRecord>,
}

#[derive(Serialize, Deserialize)]
struct PendingDeviceApprovalRecord {
    request_id: String,
    private_key: Vec<u8>,
    public_key: Vec<u8>,
    expires_at_unix_ms: u64,
}

impl Drop for PendingDeviceApprovalRecord {
    fn drop(&mut self) {
        self.private_key.zeroize();
    }
}

#[derive(Serialize, Deserialize)]
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
                pending_device_approvals: Vec::new(),
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

#[allow(clippy::too_many_arguments)]
pub fn restore_content_key(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
    recovery_key: Vec<u8>,
    key_version: u32,
    recovery_salt: &[u8],
    recovery_nonce: &[u8],
    recovery_ciphertext: &[u8],
) -> Result<bool, String> {
    let recovery_key = Zeroizing::new(recovery_key);
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let path = validated_vault_path(vault_path)?;
        validate_device_key(device_vault_key)?;
        validate_recovery_envelope(
            key_version,
            &recovery_key,
            recovery_salt,
            recovery_nonce,
            recovery_ciphertext,
        )?;
        let mut vault =
            read_vault(&path, &account_id, device_vault_key)?.unwrap_or_else(|| VaultPlaintext {
                format_version: 1,
                account_id: account_id.clone(),
                device_id: Uuid::new_v4().to_string(),
                content_key: None,
                pending_device_approvals: Vec::new(),
            });

        if let Some(record) = vault.content_key.as_ref() {
            if record.pending_recovery_key.is_some() {
                return Err("pending recovery key must be confirmed first".to_owned());
            }
            let Some(mut candidate) = unwrap_content_key(
                &account_id,
                key_version,
                &recovery_key,
                recovery_salt,
                recovery_nonce,
                recovery_ciphertext,
            )?
            else {
                return Ok(false);
            };
            let matches = constant_time_bytes_equal(&candidate, &record.cmk);
            candidate.zeroize();
            return Ok(matches);
        }

        let Some(cmk) = unwrap_content_key(
            &account_id,
            key_version,
            &recovery_key,
            recovery_salt,
            recovery_nonce,
            recovery_ciphertext,
        )?
        else {
            return Ok(false);
        };
        vault.content_key = Some(ContentKeyRecord {
            key_version,
            cmk,
            recovery_salt: recovery_salt.to_vec(),
            recovery_nonce: recovery_nonce.to_vec(),
            recovery_ciphertext: recovery_ciphertext.to_vec(),
            pending_recovery_key: None,
        });
        write_vault(&path, &account_id, device_vault_key, &vault)?;
        Ok(true)
    })
}

pub fn create_device_approval_request(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
    request_id: &str,
    expires_at_unix_ms: u64,
) -> Result<DeviceApprovalRequestKey, String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let request_id = canonical_request_id(request_id)?;
        let path = validated_vault_path(vault_path)?;
        validate_device_key(device_vault_key)?;
        let now = unix_time_ms()?;
        if expires_at_unix_ms <= now
            || expires_at_unix_ms.saturating_sub(now) > DEVICE_APPROVAL_MAX_LIFETIME_MS
        {
            return Err("device approval expiry is invalid".to_owned());
        }
        let mut vault =
            read_vault(&path, &account_id, device_vault_key)?.unwrap_or_else(|| VaultPlaintext {
                format_version: 1,
                account_id: account_id.clone(),
                device_id: Uuid::new_v4().to_string(),
                content_key: None,
                pending_device_approvals: Vec::new(),
            });
        if vault.content_key.is_some() {
            return Err("content key is already available on this device".to_owned());
        }
        vault
            .pending_device_approvals
            .retain(|pending| pending.expires_at_unix_ms > now);
        if let Some(existing) = vault
            .pending_device_approvals
            .iter()
            .find(|pending| pending.request_id == request_id)
        {
            return Ok(DeviceApprovalRequestKey {
                public_key: existing.public_key.clone(),
                verification_code: verification_code(
                    &account_id,
                    &request_id,
                    &existing.public_key,
                )?,
            });
        }
        if vault.pending_device_approvals.len() >= DEVICE_APPROVAL_MAX_PENDING {
            return Err("too many pending device approval requests".to_owned());
        }
        let mut private_key = vec![0_u8; KEY_BYTES];
        getrandom::fill(&mut private_key)
            .map_err(|_| "secure random generation failed".to_owned())?;
        let private_array: [u8; KEY_BYTES] = private_key
            .as_slice()
            .try_into()
            .map_err(|_| "device approval private key is invalid".to_owned())?;
        let public_key = X25519_BASEPOINT
            .mul_clamped(private_array)
            .to_bytes()
            .to_vec();
        let code = verification_code(&account_id, &request_id, &public_key)?;
        vault
            .pending_device_approvals
            .push(PendingDeviceApprovalRecord {
                request_id,
                private_key,
                public_key: public_key.clone(),
                expires_at_unix_ms,
            });
        write_vault(&path, &account_id, device_vault_key, &vault)?;
        Ok(DeviceApprovalRequestKey {
            public_key,
            verification_code: code,
        })
    })
}

pub fn discard_device_approval_request(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
    request_id: &str,
) -> Result<(), String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let request_id = canonical_request_id(request_id)?;
        let path = validated_vault_path(vault_path)?;
        let Some(mut vault) = read_vault(&path, &account_id, device_vault_key)? else {
            return Ok(());
        };
        let previous = vault.pending_device_approvals.len();
        vault
            .pending_device_approvals
            .retain(|pending| pending.request_id != request_id);
        if vault.pending_device_approvals.len() == previous {
            return Ok(());
        }
        write_vault(&path, &account_id, device_vault_key, &vault)
    })
}

pub fn device_approval_verification_code(
    account_id: &str,
    request_id: &str,
    requester_public_key: &[u8],
) -> Result<String, String> {
    let account_id = canonical_account_id(account_id)?;
    let request_id = canonical_request_id(request_id)?;
    verification_code(&account_id, &request_id, requester_public_key)
}

pub fn approve_device_request(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
    request_id: &str,
    requester_public_key: &[u8],
) -> Result<DeviceApprovalPackage, String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let request_id = canonical_request_id(request_id)?;
        let requester_public_key = validate_approval_public_key(requester_public_key)?;
        let path = validated_vault_path(vault_path)?;
        let vault = read_vault(&path, &account_id, device_vault_key)?
            .ok_or_else(|| "content key is not initialized".to_owned())?;
        let record = vault
            .content_key
            .as_ref()
            .filter(|record| record.pending_recovery_key.is_none())
            .ok_or_else(|| "content key is not ready".to_owned())?;

        let mut private_key = Zeroizing::new([0_u8; KEY_BYTES]);
        getrandom::fill(&mut *private_key)
            .map_err(|_| "secure random generation failed".to_owned())?;
        let approver_public_key = X25519_BASEPOINT.mul_clamped(*private_key).to_bytes();
        let shared_secret = Zeroizing::new(
            MontgomeryPoint(requester_public_key)
                .mul_clamped(*private_key)
                .to_bytes(),
        );
        if all_zero(&shared_secret[..]) {
            return Err("device approval public key is invalid".to_owned());
        }
        let context = device_approval_context(
            &account_id,
            &request_id,
            record.key_version,
            &requester_public_key,
            &approver_public_key,
        );
        let mut kek = Zeroizing::new([0_u8; KEY_BYTES]);
        Hkdf::<Sha256>::new(Some(request_id.as_bytes()), &shared_secret[..])
            .expand(&context, &mut *kek)
            .map_err(|_| "device approval key derivation failed".to_owned())?;
        let mut nonce = [0_u8; DEVICE_APPROVAL_NONCE_BYTES];
        getrandom::fill(&mut nonce).map_err(|_| "secure random generation failed".to_owned())?;
        let cipher = Aes256Gcm::new_from_slice(&*kek)
            .map_err(|_| "device approval key derivation failed".to_owned())?;
        let nonce_ref = Nonce::try_from(nonce.as_slice())
            .map_err(|_| "device approval nonce is invalid".to_owned())?;
        let ciphertext = cipher
            .encrypt(
                &nonce_ref,
                Payload {
                    msg: &record.cmk,
                    aad: &context,
                },
            )
            .map_err(|_| "content key device wrapping failed".to_owned())?;
        Ok(DeviceApprovalPackage {
            approver_public_key: approver_public_key.to_vec(),
            nonce: nonce.to_vec(),
            ciphertext,
            key_version: record.key_version,
            verification_code: verification_code(&account_id, &request_id, &requester_public_key)?,
        })
    })
}

#[allow(clippy::too_many_arguments)]
pub fn complete_device_approval(
    vault_path: &str,
    account_id: &str,
    device_vault_key: &[u8],
    request_id: &str,
    approver_public_key: &[u8],
    nonce: &[u8],
    ciphertext: &[u8],
    key_version: u32,
    recovery_salt: &[u8],
    recovery_nonce: &[u8],
    recovery_ciphertext: &[u8],
) -> Result<bool, String> {
    with_vault_lock(|| {
        let account_id = canonical_account_id(account_id)?;
        let request_id = canonical_request_id(request_id)?;
        let approver_public_key = validate_approval_public_key(approver_public_key)?;
        if nonce.len() != DEVICE_APPROVAL_NONCE_BYTES || ciphertext.len() != KEY_BYTES + 16 {
            return Err("device approval package is invalid".to_owned());
        }
        validate_stored_recovery_metadata(
            key_version,
            recovery_salt,
            recovery_nonce,
            recovery_ciphertext,
        )?;
        let path = validated_vault_path(vault_path)?;
        let mut vault = read_vault(&path, &account_id, device_vault_key)?
            .ok_or_else(|| "device approval request is missing".to_owned())?;
        if vault.content_key.is_some() {
            return Err("content key is already available on this device".to_owned());
        }
        let position = vault
            .pending_device_approvals
            .iter()
            .position(|pending| pending.request_id == request_id)
            .ok_or_else(|| "device approval request is missing".to_owned())?;
        let pending = vault.pending_device_approvals.remove(position);
        if pending.expires_at_unix_ms <= unix_time_ms()? {
            return Err("device approval request has expired".to_owned());
        }
        let requester_public_key: [u8; KEY_BYTES] = pending
            .public_key
            .as_slice()
            .try_into()
            .map_err(|_| "device approval request is invalid".to_owned())?;
        let private_key = Zeroizing::new(
            pending
                .private_key
                .as_slice()
                .try_into()
                .map_err(|_| "device approval request is invalid".to_owned())?,
        );
        let shared_secret = Zeroizing::new(
            MontgomeryPoint(approver_public_key)
                .mul_clamped(*private_key)
                .to_bytes(),
        );
        if all_zero(&shared_secret[..]) {
            return Ok(false);
        }
        let context = device_approval_context(
            &account_id,
            &request_id,
            key_version,
            &requester_public_key,
            &approver_public_key,
        );
        let mut kek = Zeroizing::new([0_u8; KEY_BYTES]);
        Hkdf::<Sha256>::new(Some(request_id.as_bytes()), &shared_secret[..])
            .expand(&context, &mut *kek)
            .map_err(|_| "device approval key derivation failed".to_owned())?;
        let cipher = Aes256Gcm::new_from_slice(&*kek)
            .map_err(|_| "device approval key derivation failed".to_owned())?;
        let nonce_ref =
            Nonce::try_from(nonce).map_err(|_| "device approval package is invalid".to_owned())?;
        let decrypted = cipher.decrypt(
            &nonce_ref,
            Payload {
                msg: ciphertext,
                aad: &context,
            },
        );
        let Ok(mut cmk) = decrypted else {
            return Ok(false);
        };
        if cmk.len() != KEY_BYTES {
            cmk.zeroize();
            return Ok(false);
        }
        vault.content_key = Some(ContentKeyRecord {
            key_version,
            cmk,
            recovery_salt: recovery_salt.to_vec(),
            recovery_nonce: recovery_nonce.to_vec(),
            recovery_ciphertext: recovery_ciphertext.to_vec(),
            pending_recovery_key: None,
        });
        write_vault(&path, &account_id, device_vault_key, &vault)?;
        Ok(true)
    })
}

fn verification_code(
    account_id: &str,
    request_id: &str,
    requester_public_key: &[u8],
) -> Result<String, String> {
    let public_key = validate_approval_public_key(requester_public_key)?;
    let mut digest = Sha256::new();
    digest.update(b"daylink-device-approval-code-v1\0");
    digest.update(account_id.as_bytes());
    digest.update(b"\0");
    digest.update(request_id.as_bytes());
    digest.update(b"\0");
    digest.update(public_key);
    let output = digest.finalize();
    let value = u32::from_be_bytes(
        output[..4]
            .try_into()
            .map_err(|_| "device approval verification code could not be generated".to_owned())?,
    ) % 1_000_000;
    Ok(format!("{:03} {:03}", value / 1_000, value % 1_000))
}

fn device_approval_context(
    account_id: &str,
    request_id: &str,
    key_version: u32,
    requester_public_key: &[u8; KEY_BYTES],
    approver_public_key: &[u8; KEY_BYTES],
) -> Vec<u8> {
    let mut context = Vec::with_capacity(180);
    context.extend_from_slice(b"daylink-device-approval-envelope-v1\0");
    context.extend_from_slice(account_id.as_bytes());
    context.push(0);
    context.extend_from_slice(request_id.as_bytes());
    context.push(0);
    context.extend_from_slice(&key_version.to_be_bytes());
    context.extend_from_slice(requester_public_key);
    context.extend_from_slice(approver_public_key);
    context
}

fn validate_approval_public_key(value: &[u8]) -> Result<[u8; KEY_BYTES], String> {
    let key: [u8; KEY_BYTES] = value
        .try_into()
        .map_err(|_| "device approval public key is invalid".to_owned())?;
    if all_zero(&key) {
        return Err("device approval public key is invalid".to_owned());
    }
    Ok(key)
}

fn validate_stored_recovery_metadata(
    key_version: u32,
    salt: &[u8],
    nonce: &[u8],
    ciphertext: &[u8],
) -> Result<(), String> {
    if key_version != CONTENT_KEY_VERSION
        || salt.len() != RECOVERY_SALT_BYTES
        || nonce.len() != RECOVERY_NONCE_BYTES
        || ciphertext.len() != KEY_BYTES + 16
    {
        return Err("recovery envelope is invalid".to_owned());
    }
    Ok(())
}

fn canonical_request_id(value: &str) -> Result<String, String> {
    let parsed =
        Uuid::parse_str(value).map_err(|_| "device approval request ID is invalid".to_owned())?;
    let canonical = parsed.hyphenated().to_string();
    if value.to_ascii_lowercase() != canonical {
        return Err("device approval request ID is not canonical".to_owned());
    }
    Ok(canonical)
}

fn unix_time_ms() -> Result<u64, String> {
    let elapsed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| "system clock is invalid".to_owned())?;
    u64::try_from(elapsed.as_millis()).map_err(|_| "system clock is invalid".to_owned())
}

fn all_zero(value: &[u8]) -> bool {
    value.iter().fold(0_u8, |aggregate, item| aggregate | item) == 0
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

fn unwrap_content_key(
    account_id: &str,
    key_version: u32,
    recovery_key: &[u8],
    salt: &[u8],
    nonce: &[u8],
    ciphertext: &[u8],
) -> Result<Option<Vec<u8>>, String> {
    let hkdf = Hkdf::<Sha256>::new(Some(salt), recovery_key);
    let mut kek = [0_u8; KEY_BYTES];
    let info = format!("daylink-recovery-kek-v1\0{account_id}\0{key_version}");
    hkdf.expand(info.as_bytes(), &mut kek)
        .map_err(|_| "recovery key derivation failed".to_owned())?;
    let cipher =
        Aes256Gcm::new_from_slice(&kek).map_err(|_| "recovery key derivation failed".to_owned())?;
    let aad = format!("daylink-recovery-envelope-v1\0{account_id}\0{key_version}");
    let nonce = Nonce::try_from(nonce).map_err(|_| "recovery nonce is invalid".to_owned())?;
    let decrypted = cipher.decrypt(
        &nonce,
        Payload {
            msg: ciphertext,
            aad: aad.as_bytes(),
        },
    );
    kek.zeroize();
    let Ok(mut cmk) = decrypted else {
        return Ok(None);
    };
    if cmk.len() != KEY_BYTES {
        cmk.zeroize();
        return Err("recovery envelope plaintext is invalid".to_owned());
    }
    Ok(Some(cmk))
}

fn validate_recovery_envelope(
    key_version: u32,
    recovery_key: &[u8],
    salt: &[u8],
    nonce: &[u8],
    ciphertext: &[u8],
) -> Result<(), String> {
    if key_version != CONTENT_KEY_VERSION
        || recovery_key.len() != KEY_BYTES
        || salt.len() != RECOVERY_SALT_BYTES
        || nonce.len() != RECOVERY_NONCE_BYTES
        || ciphertext.len() != KEY_BYTES + 16
    {
        return Err("recovery envelope is invalid".to_owned());
    }
    Ok(())
}

fn constant_time_bytes_equal(left: &[u8], right: &[u8]) -> bool {
    if left.len() != right.len() {
        return false;
    }
    let mut difference = 0_u8;
    for (left, right) in left.iter().zip(right) {
        difference |= left ^ right;
    }
    difference == 0
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
    validate_pending_device_approvals(&decoded.pending_device_approvals)?;
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
    validate_pending_device_approvals(&vault.pending_device_approvals)?;
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

fn validate_pending_device_approvals(
    approvals: &[PendingDeviceApprovalRecord],
) -> Result<(), String> {
    if approvals.len() > DEVICE_APPROVAL_MAX_PENDING
        || approvals.iter().any(|approval| {
            Uuid::parse_str(&approval.request_id).is_err()
                || approval.private_key.len() != KEY_BYTES
                || approval.public_key.len() != DEVICE_APPROVAL_PUBLIC_KEY_BYTES
                || all_zero(&approval.private_key)
                || all_zero(&approval.public_key)
                || approval.expires_at_unix_ms == 0
        })
    {
        return Err("vault device approval record is invalid".to_owned());
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
        let debug = format!("{first:?}");
        assert!(debug.contains("<redacted>"));
        assert!(!debug.contains("recovery_key: ["));
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

    #[test]
    fn recovery_key_restores_the_same_cmk_on_a_new_device() {
        let source_path = test_path("restore-source");
        let destination_path = test_path("restore-destination");
        let account = "8f2e0a0d-574b-4e53-bf82-1ec9c9bc2521";
        let source_device_key = generate_device_vault_key().expect("source device key");
        let destination_device_key = generate_device_vault_key().expect("destination device key");
        let initialized = initialize_content_key(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
        )
        .expect("initialize");

        assert!(
            restore_content_key(
                destination_path.to_str().expect("destination path"),
                account,
                &destination_device_key,
                initialized.recovery_key.clone(),
                initialized.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &initialized.recovery_ciphertext,
            )
            .expect("restore")
        );
        assert!(
            restore_content_key(
                destination_path.to_str().expect("destination path"),
                account,
                &destination_device_key,
                initialized.recovery_key.clone(),
                initialized.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &initialized.recovery_ciphertext,
            )
            .expect("idempotent restore")
        );
        assert_eq!(
            content_key_status(
                destination_path.to_str().expect("destination path"),
                account,
                &destination_device_key,
            )
            .expect("status"),
            ContentKeyStatus::Ready
        );

        let source = read_vault(&source_path, account, &source_device_key)
            .expect("read source")
            .expect("source vault");
        let destination = read_vault(&destination_path, account, &destination_device_key)
            .expect("read destination")
            .expect("destination vault");
        let source_key = source.content_key.expect("source key");
        let destination_key = destination.content_key.expect("destination key");
        assert!(constant_time_bytes_equal(
            &source_key.cmk,
            &destination_key.cmk
        ));
        let destination_bytes = fs::read(&destination_path).expect("read destination bytes");
        assert!(
            !destination_bytes
                .windows(initialized.recovery_key.len())
                .any(|part| part == initialized.recovery_key)
        );

        let _ = fs::remove_dir_all(source_path.parent().expect("source parent"));
        let _ = fs::remove_dir_all(destination_path.parent().expect("destination parent"));
    }

    #[test]
    fn wrong_or_cross_account_recovery_key_never_creates_a_content_key() {
        let source_path = test_path("restore-reject-source");
        let wrong_key_path = test_path("restore-reject-wrong-key");
        let cross_account_path = test_path("restore-reject-cross-account");
        let tampered_path = test_path("restore-reject-tampered");
        let account = "8f2e0a0d-574b-4e53-bf82-1ec9c9bc2521";
        let other_account = "123e4567-e89b-42d3-a456-426614174000";
        let source_device_key = generate_device_vault_key().expect("source device key");
        let destination_device_key = generate_device_vault_key().expect("destination device key");
        let initialized = initialize_content_key(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
        )
        .expect("initialize");
        let mut wrong_key = initialized.recovery_key.clone();
        wrong_key[0] ^= 1;

        assert!(
            !restore_content_key(
                wrong_key_path.to_str().expect("wrong key path"),
                account,
                &destination_device_key,
                wrong_key,
                initialized.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &initialized.recovery_ciphertext,
            )
            .expect("reject wrong key")
        );
        assert!(!wrong_key_path.exists());

        let mut tampered_ciphertext = initialized.recovery_ciphertext.clone();
        tampered_ciphertext[0] ^= 1;
        assert!(
            !restore_content_key(
                tampered_path.to_str().expect("tampered path"),
                account,
                &destination_device_key,
                initialized.recovery_key.clone(),
                initialized.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &tampered_ciphertext,
            )
            .expect("reject tampered envelope")
        );
        assert!(!tampered_path.exists());

        assert!(
            !restore_content_key(
                cross_account_path.to_str().expect("cross-account path"),
                other_account,
                &destination_device_key,
                initialized.recovery_key,
                initialized.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &initialized.recovery_ciphertext,
            )
            .expect("reject cross-account envelope")
        );
        assert!(!cross_account_path.exists());

        let _ = fs::remove_dir_all(source_path.parent().expect("source parent"));
        let _ = fs::remove_dir_all(wrong_key_path.parent().expect("wrong key parent"));
        let _ = fs::remove_dir_all(cross_account_path.parent().expect("cross-account parent"));
        let _ = fs::remove_dir_all(tampered_path.parent().expect("tampered parent"));
    }

    #[test]
    fn trusted_device_approval_transfers_the_same_cmk_without_server_plaintext() {
        let source_path = test_path("approval-source");
        let destination_path = test_path("approval-destination");
        let account = "8f2e0a0d-574b-4e53-bf82-1ec9c9bc2521";
        let request_id = Uuid::new_v4().to_string();
        let source_device_key = generate_device_vault_key().expect("source device key");
        let destination_device_key = generate_device_vault_key().expect("destination device key");
        let initialized = initialize_content_key(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
        )
        .expect("initialize source");
        acknowledge_recovery_key_saved(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
        )
        .expect("confirm source");
        let request = create_device_approval_request(
            destination_path.to_str().expect("destination path"),
            account,
            &destination_device_key,
            &request_id,
            unix_time_ms().expect("clock") + 600_000,
        )
        .expect("create request");
        let package = approve_device_request(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
            &request_id,
            &request.public_key,
        )
        .expect("approve request");
        assert_eq!(request.verification_code, package.verification_code);
        assert_eq!(request.verification_code.len(), 7);
        assert!(request.verification_code.as_bytes()[3] == b' ');
        assert!(
            complete_device_approval(
                destination_path.to_str().expect("destination path"),
                account,
                &destination_device_key,
                &request_id,
                &package.approver_public_key,
                &package.nonce,
                &package.ciphertext,
                package.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &initialized.recovery_ciphertext,
            )
            .expect("complete request")
        );
        let source = read_vault(&source_path, account, &source_device_key)
            .expect("read source")
            .expect("source vault");
        let destination = read_vault(&destination_path, account, &destination_device_key)
            .expect("read destination")
            .expect("destination vault");
        assert!(constant_time_bytes_equal(
            &source.content_key.expect("source content key").cmk,
            &destination
                .content_key
                .expect("destination content key")
                .cmk,
        ));
        let encrypted_vault = fs::read(&destination_path).expect("encrypted destination vault");
        assert!(
            !encrypted_vault
                .windows(request.public_key.len())
                .any(|window| window == request.public_key)
        );
        let debug = format!("{package:?}");
        assert!(!debug.contains("ciphertext: ["));

        let _ = fs::remove_dir_all(source_path.parent().expect("source parent"));
        let _ = fs::remove_dir_all(destination_path.parent().expect("destination parent"));
    }

    #[test]
    fn trusted_device_approval_rejects_tampering_and_expired_requests() {
        let source_path = test_path("approval-reject-source");
        let destination_path = test_path("approval-reject-destination");
        let account = "8f2e0a0d-574b-4e53-bf82-1ec9c9bc2521";
        let request_id = Uuid::new_v4().to_string();
        let source_device_key = generate_device_vault_key().expect("source device key");
        let destination_device_key = generate_device_vault_key().expect("destination device key");
        let initialized = initialize_content_key(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
        )
        .expect("initialize source");
        acknowledge_recovery_key_saved(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
        )
        .expect("confirm source");
        let request = create_device_approval_request(
            destination_path.to_str().expect("destination path"),
            account,
            &destination_device_key,
            &request_id,
            unix_time_ms().expect("clock") + 600_000,
        )
        .expect("create request");
        let package = approve_device_request(
            source_path.to_str().expect("source path"),
            account,
            &source_device_key,
            &request_id,
            &request.public_key,
        )
        .expect("approve request");
        let mut tampered = package.ciphertext.clone();
        tampered[0] ^= 1;
        assert!(
            !complete_device_approval(
                destination_path.to_str().expect("destination path"),
                account,
                &destination_device_key,
                &request_id,
                &package.approver_public_key,
                &package.nonce,
                &tampered,
                package.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &initialized.recovery_ciphertext,
            )
            .expect("reject tampering")
        );
        assert_eq!(
            content_key_status(
                destination_path.to_str().expect("destination path"),
                account,
                &destination_device_key,
            )
            .expect("status"),
            ContentKeyStatus::Missing,
        );
        let mut destination = read_vault(&destination_path, account, &destination_device_key)
            .expect("read destination")
            .expect("destination vault");
        destination.pending_device_approvals[0].expires_at_unix_ms =
            unix_time_ms().expect("clock") - 1;
        write_vault(
            &destination_path,
            account,
            &destination_device_key,
            &destination,
        )
        .expect("write expired request");
        assert!(
            complete_device_approval(
                destination_path.to_str().expect("destination path"),
                account,
                &destination_device_key,
                &request_id,
                &package.approver_public_key,
                &package.nonce,
                &package.ciphertext,
                package.key_version,
                &initialized.recovery_salt,
                &initialized.recovery_nonce,
                &initialized.recovery_ciphertext,
            )
            .is_err()
        );

        let _ = fs::remove_dir_all(source_path.parent().expect("source parent"));
        let _ = fs::remove_dir_all(destination_path.parent().expect("destination parent"));
    }
}
