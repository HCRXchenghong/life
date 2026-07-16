//! Stable Flutter-facing facade. Internal `russh` and protocol types never
//! cross the FFI boundary.

#![forbid(unsafe_code)]
#![allow(unexpected_cfgs)]

use std::fmt;
use std::net::IpAddr;
use std::sync::Arc;
use std::time::Duration;

use daylink_protocol::{AgentRequest, AgentResponse, Envelope};
use flutter_rust_bridge::frb;
use tokio::net::TcpListener;
use tokio::sync::{Mutex, watch};
use tokio::task::JoinHandle;
use zeroize::Zeroize;

use crate::vault;
use crate::{
    AgentChannel, AgentInstallResult, Authentication, CommandOutput, ConnectionConfig, HostKey,
    PtySession, SshSession, TerminalEvent, probe_host_key,
};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[must_use]
pub fn core_api_version() -> String {
    env!("CARGO_PKG_VERSION").to_owned()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BridgeContentKeyStatus {
    Missing,
    PendingRecoveryConfirmation,
    Ready,
}

#[derive(Clone)]
pub struct BridgeContentKeyInitialization {
    pub device_id: String,
    pub key_version: u32,
    pub recovery_key: Vec<u8>,
    pub recovery_salt: Vec<u8>,
    pub recovery_nonce: Vec<u8>,
    pub recovery_ciphertext: Vec<u8>,
}

#[derive(Clone)]
pub struct BridgeDeviceApprovalRequestKey {
    pub request_id: String,
    pub public_key: Vec<u8>,
    pub request_token: Vec<u8>,
    pub verification_code: String,
    pub expires_at_unix_ms: u64,
}

impl fmt::Debug for BridgeDeviceApprovalRequestKey {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("BridgeDeviceApprovalRequestKey")
            .field("request_id", &self.request_id)
            .field("public_key_bytes", &self.public_key.len())
            .field("request_token", &"<redacted>")
            .field("verification_code", &"<redacted>")
            .field("expires_at_unix_ms", &self.expires_at_unix_ms)
            .finish()
    }
}

#[derive(Clone)]
pub struct BridgeDeviceApprovalPackage {
    pub approver_public_key: Vec<u8>,
    pub nonce: Vec<u8>,
    pub ciphertext: Vec<u8>,
    pub key_version: u32,
    pub verification_code: String,
}

impl fmt::Debug for BridgeDeviceApprovalPackage {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("BridgeDeviceApprovalPackage")
            .field("approver_public_key_bytes", &self.approver_public_key.len())
            .field("nonce_bytes", &self.nonce.len())
            .field("ciphertext_bytes", &self.ciphertext.len())
            .field("key_version", &self.key_version)
            .field("verification_code", &self.verification_code)
            .finish()
    }
}

impl fmt::Debug for BridgeContentKeyInitialization {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("BridgeContentKeyInitialization")
            .field("device_id", &self.device_id)
            .field("key_version", &self.key_version)
            .field("recovery_key", &"<redacted>")
            .field("recovery_salt_bytes", &self.recovery_salt.len())
            .field("recovery_nonce_bytes", &self.recovery_nonce.len())
            .field("recovery_ciphertext_bytes", &self.recovery_ciphertext.len())
            .finish()
    }
}

pub fn generate_device_vault_key() -> Result<Vec<u8>, String> {
    vault::generate_device_vault_key()
}

#[allow(clippy::needless_pass_by_value)] // FRB owns and transfers these values across the FFI boundary.
pub fn content_key_status(
    vault_path: String,
    account_id: String,
    device_vault_key: Vec<u8>,
) -> Result<BridgeContentKeyStatus, String> {
    vault::content_key_status(&vault_path, &account_id, &device_vault_key).map(
        |status| match status {
            vault::ContentKeyStatus::Missing => BridgeContentKeyStatus::Missing,
            vault::ContentKeyStatus::PendingRecoveryConfirmation => {
                BridgeContentKeyStatus::PendingRecoveryConfirmation
            }
            vault::ContentKeyStatus::Ready => BridgeContentKeyStatus::Ready,
        },
    )
}

#[allow(clippy::needless_pass_by_value)] // FRB owns and transfers these values across the FFI boundary.
pub fn initialize_content_key(
    vault_path: String,
    account_id: String,
    device_vault_key: Vec<u8>,
) -> Result<BridgeContentKeyInitialization, String> {
    vault::initialize_content_key(&vault_path, &account_id, &device_vault_key).map(|result| {
        BridgeContentKeyInitialization {
            device_id: result.device_id,
            key_version: result.key_version,
            recovery_key: result.recovery_key,
            recovery_salt: result.recovery_salt,
            recovery_nonce: result.recovery_nonce,
            recovery_ciphertext: result.recovery_ciphertext,
        }
    })
}

#[allow(clippy::needless_pass_by_value)] // FRB owns and transfers these values across the FFI boundary.
pub fn acknowledge_recovery_key_saved(
    vault_path: String,
    account_id: String,
    device_vault_key: Vec<u8>,
) -> Result<(), String> {
    vault::acknowledge_recovery_key_saved(&vault_path, &account_id, &device_vault_key)
}

#[allow(clippy::needless_pass_by_value)] // FRB owns and transfers these values across the FFI boundary.
pub fn discard_pending_content_key(
    vault_path: String,
    account_id: String,
    device_vault_key: Vec<u8>,
) -> Result<(), String> {
    vault::discard_pending_content_key(&vault_path, &account_id, &device_vault_key)
}

#[allow(clippy::too_many_arguments, clippy::needless_pass_by_value)]
pub fn restore_content_key(
    vault_path: String,
    account_id: String,
    mut device_vault_key: Vec<u8>,
    recovery_key: Vec<u8>,
    key_version: u32,
    recovery_salt: Vec<u8>,
    recovery_nonce: Vec<u8>,
    recovery_ciphertext: Vec<u8>,
) -> Result<bool, String> {
    let result = vault::restore_content_key(
        &vault_path,
        &account_id,
        &device_vault_key,
        recovery_key,
        key_version,
        &recovery_salt,
        &recovery_nonce,
        &recovery_ciphertext,
    );
    device_vault_key.zeroize();
    result
}

#[allow(clippy::needless_pass_by_value)]
pub fn create_device_approval_request(
    vault_path: String,
    account_id: String,
    mut device_vault_key: Vec<u8>,
    request_id: String,
    expires_at_unix_ms: u64,
) -> Result<BridgeDeviceApprovalRequestKey, String> {
    let result = vault::create_device_approval_request(
        &vault_path,
        &account_id,
        &device_vault_key,
        &request_id,
        expires_at_unix_ms,
    )
    .map(|request| BridgeDeviceApprovalRequestKey {
        request_id: request.request_id,
        public_key: request.public_key,
        request_token: request.request_token,
        verification_code: request.verification_code,
        expires_at_unix_ms: request.expires_at_unix_ms,
    });
    device_vault_key.zeroize();
    result
}

#[allow(clippy::needless_pass_by_value)]
pub fn load_device_approval_request(
    vault_path: String,
    account_id: String,
    mut device_vault_key: Vec<u8>,
) -> Result<Option<BridgeDeviceApprovalRequestKey>, String> {
    let result = vault::load_device_approval_request(&vault_path, &account_id, &device_vault_key)
        .map(|request| {
            request.map(|request| BridgeDeviceApprovalRequestKey {
                request_id: request.request_id,
                public_key: request.public_key,
                request_token: request.request_token,
                verification_code: request.verification_code,
                expires_at_unix_ms: request.expires_at_unix_ms,
            })
        });
    device_vault_key.zeroize();
    result
}

#[allow(clippy::needless_pass_by_value)]
pub fn discard_device_approval_request(
    vault_path: String,
    account_id: String,
    mut device_vault_key: Vec<u8>,
    request_id: String,
) -> Result<(), String> {
    let result = vault::discard_device_approval_request(
        &vault_path,
        &account_id,
        &device_vault_key,
        &request_id,
    );
    device_vault_key.zeroize();
    result
}

#[allow(clippy::needless_pass_by_value)]
pub fn device_approval_verification_code(
    account_id: String,
    request_id: String,
    requester_public_key: Vec<u8>,
) -> Result<String, String> {
    vault::device_approval_verification_code(&account_id, &request_id, &requester_public_key)
}

#[allow(clippy::needless_pass_by_value)]
pub fn approve_device_request(
    vault_path: String,
    account_id: String,
    mut device_vault_key: Vec<u8>,
    request_id: String,
    requester_public_key: Vec<u8>,
) -> Result<BridgeDeviceApprovalPackage, String> {
    let result = vault::approve_device_request(
        &vault_path,
        &account_id,
        &device_vault_key,
        &request_id,
        &requester_public_key,
    )
    .map(|package| BridgeDeviceApprovalPackage {
        approver_public_key: package.approver_public_key,
        nonce: package.nonce,
        ciphertext: package.ciphertext,
        key_version: package.key_version,
        verification_code: package.verification_code,
    });
    device_vault_key.zeroize();
    result
}

#[allow(clippy::too_many_arguments, clippy::needless_pass_by_value)]
pub fn complete_device_approval(
    vault_path: String,
    account_id: String,
    mut device_vault_key: Vec<u8>,
    request_id: String,
    approver_public_key: Vec<u8>,
    nonce: Vec<u8>,
    ciphertext: Vec<u8>,
    key_version: u32,
    recovery_salt: Vec<u8>,
    recovery_nonce: Vec<u8>,
    recovery_ciphertext: Vec<u8>,
) -> Result<bool, String> {
    let result = vault::complete_device_approval(
        &vault_path,
        &account_id,
        &device_vault_key,
        &request_id,
        &approver_public_key,
        &nonce,
        &ciphertext,
        key_version,
        &recovery_salt,
        &recovery_nonce,
        &recovery_ciphertext,
    );
    device_vault_key.zeroize();
    result
}

#[derive(Debug, Clone)]
pub struct BridgeHostKey {
    pub algorithm: String,
    pub fingerprint_sha256: String,
}

impl From<HostKey> for BridgeHostKey {
    fn from(value: HostKey) -> Self {
        Self {
            algorithm: value.algorithm,
            fingerprint_sha256: value.fingerprint_sha256,
        }
    }
}

pub async fn probe_host_key_mobile(
    host: String,
    port: u16,
    timeout_ms: u64,
) -> Result<BridgeHostKey, String> {
    validate_host_and_port(&host, port)?;
    probe_host_key(&host, port, bounded_timeout(timeout_ms))
        .await
        .map(Into::into)
        .map_err(|error| error.to_string())
}

#[derive(Debug, Clone)]
pub struct BridgeConnectionConfig {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub accepted_host_key_sha256: String,
    pub connect_timeout_ms: u64,
    pub inactivity_timeout_ms: u64,
}

#[derive(Debug, Clone)]
pub enum BridgeAuthentication {
    Password {
        password: String,
    },
    PrivateKey {
        pem: String,
        passphrase: Option<String>,
    },
}

#[derive(Debug, Clone)]
pub struct BridgeCommandOutput {
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub exit_status: Option<u32>,
}

#[derive(Debug, Clone)]
pub struct BridgeAgentInstallResult {
    pub version: String,
    pub remote_path: String,
    pub sha256: String,
}

impl From<AgentInstallResult> for BridgeAgentInstallResult {
    fn from(value: AgentInstallResult) -> Self {
        Self {
            version: value.version,
            remote_path: value.remote_path,
            sha256: value.sha256,
        }
    }
}

impl From<CommandOutput> for BridgeCommandOutput {
    fn from(value: CommandOutput) -> Self {
        Self {
            stdout: value.stdout,
            stderr: value.stderr,
            exit_status: value.exit_status,
        }
    }
}

#[frb(opaque)]
pub struct MobileSshSession {
    inner: Arc<SshSession>,
}

impl MobileSshSession {
    pub async fn connect(
        config: BridgeConnectionConfig,
        authentication: BridgeAuthentication,
    ) -> Result<MobileSshSession, String> {
        validate_host_and_port(&config.host, config.port)?;
        if config.username.trim().is_empty() {
            return Err("username must not be empty".to_owned());
        }
        if config.accepted_host_key_sha256.trim().is_empty() {
            return Err("an explicitly accepted host key is required".to_owned());
        }
        let auth = match authentication {
            BridgeAuthentication::Password { password } => Authentication::Password(password),
            BridgeAuthentication::PrivateKey { pem, passphrase } => {
                Authentication::PrivateKey { pem, passphrase }
            }
        };
        let session = SshSession::connect(
            &ConnectionConfig {
                host: config.host,
                port: config.port,
                username: config.username,
                accepted_host_key_sha256: config.accepted_host_key_sha256,
                connect_timeout: bounded_timeout(config.connect_timeout_ms),
                inactivity_timeout: bounded_timeout(config.inactivity_timeout_ms),
            },
            auth,
        )
        .await
        .map_err(|error| error.to_string())?;
        Ok(Self {
            inner: Arc::new(session),
        })
    }

    pub async fn execute(&self, command: String) -> Result<BridgeCommandOutput, String> {
        if command.trim().is_empty() {
            return Err("command must not be empty".to_owned());
        }
        self.inner
            .execute(&command)
            .await
            .map(Into::into)
            .map_err(|error| error.to_string())
    }

    pub async fn install_agent(
        &self,
        binary: Vec<u8>,
        version: String,
        expected_sha256: String,
    ) -> Result<BridgeAgentInstallResult, String> {
        self.inner
            .install_agent(&binary, &version, &expected_sha256)
            .await
            .map(Into::into)
            .map_err(|error| error.to_string())
    }

    pub async fn open_terminal(
        &self,
        term: String,
        columns: u32,
        rows: u32,
    ) -> Result<MobileTerminal, String> {
        if columns == 0 || rows == 0 {
            return Err("terminal dimensions must be positive".to_owned());
        }
        let terminal = self
            .inner
            .open_terminal(&term, columns, rows)
            .await
            .map_err(|error| error.to_string())?;
        Ok(MobileTerminal {
            inner: Mutex::new(terminal),
        })
    }

    pub async fn open_agent(&self) -> Result<MobileAgentChannel, String> {
        let channel = self
            .inner
            .open_agent()
            .await
            .map_err(|error| error.to_string())?;
        Ok(MobileAgentChannel {
            inner: Mutex::new(channel),
        })
    }

    pub async fn start_local_forward(
        &self,
        bind_address: String,
        local_port: u16,
        target_host: String,
        target_port: u16,
    ) -> Result<MobilePortForward, String> {
        validate_host_and_port(&target_host, target_port)?;
        let ip: IpAddr = bind_address
            .parse()
            .map_err(|_| "bind address must be a loopback IP address".to_owned())?;
        if !ip.is_loopback() {
            return Err("non-loopback forwarding requires a separate approval path".to_owned());
        }
        let listener = TcpListener::bind((ip, local_port))
            .await
            .map_err(|error| error.to_string())?;
        let local_address = listener
            .local_addr()
            .map_err(|error| error.to_string())?
            .to_string();
        let session = Arc::clone(&self.inner);
        let (stop, mut stop_receiver) = watch::channel(false);
        let task = tokio::spawn(async move {
            loop {
                tokio::select! {
                    changed = stop_receiver.changed() => {
                        if changed.is_err() || *stop_receiver.borrow() {
                            break;
                        }
                    }
                    accepted = listener.accept() => {
                        let Ok((stream, peer)) = accepted else { break };
                        let session = Arc::clone(&session);
                        let target_host = target_host.clone();
                        tokio::spawn(async move {
                            let _ = session
                                .forward_stream(
                                    stream,
                                    &target_host,
                                    target_port,
                                    &peer.ip().to_string(),
                                    peer.port(),
                                )
                                .await;
                        });
                    }
                }
            }
        });
        Ok(MobilePortForward {
            local_address,
            stop,
            task: Mutex::new(Some(task)),
        })
    }

    pub async fn disconnect(&self) -> Result<(), String> {
        self.inner
            .disconnect()
            .await
            .map_err(|error| error.to_string())
    }
}

#[derive(Debug, Clone)]
pub enum BridgeTerminalEvent {
    Stdout { bytes: Vec<u8> },
    Stderr { bytes: Vec<u8> },
    Exit { status: u32 },
    Closed,
}

#[frb(opaque)]
pub struct MobileTerminal {
    inner: Mutex<PtySession>,
}

impl MobileTerminal {
    pub async fn write(&self, bytes: Vec<u8>) -> Result<(), String> {
        self.inner
            .lock()
            .await
            .write(&bytes)
            .await
            .map_err(|error| error.to_string())
    }

    pub async fn resize(&self, columns: u32, rows: u32) -> Result<(), String> {
        if columns == 0 || rows == 0 {
            return Err("terminal dimensions must be positive".to_owned());
        }
        self.inner
            .lock()
            .await
            .resize(columns, rows)
            .await
            .map_err(|error| error.to_string())
    }

    pub async fn next_event(&self) -> BridgeTerminalEvent {
        match self.inner.lock().await.next_event().await {
            TerminalEvent::Stdout(bytes) => BridgeTerminalEvent::Stdout { bytes },
            TerminalEvent::Stderr(bytes) => BridgeTerminalEvent::Stderr { bytes },
            TerminalEvent::Exit(status) => BridgeTerminalEvent::Exit { status },
            TerminalEvent::Closed => BridgeTerminalEvent::Closed,
        }
    }

    pub async fn close(&self) -> Result<(), String> {
        self.inner
            .lock()
            .await
            .close()
            .await
            .map_err(|error| error.to_string())
    }
}

#[frb(opaque)]
pub struct MobileAgentChannel {
    inner: Mutex<AgentChannel>,
}

impl MobileAgentChannel {
    pub async fn request_json(
        &self,
        sent_at_unix_ms: i64,
        request_json: String,
    ) -> Result<String, String> {
        let request: AgentRequest =
            serde_json::from_str(&request_json).map_err(|error| error.to_string())?;
        let response: Envelope<AgentResponse> = self
            .inner
            .lock()
            .await
            .request(sent_at_unix_ms, request)
            .await
            .map_err(|error| error.to_string())?;
        serde_json::to_string(&response).map_err(|error| error.to_string())
    }
}

#[frb(opaque)]
pub struct MobilePortForward {
    local_address: String,
    stop: watch::Sender<bool>,
    task: Mutex<Option<JoinHandle<()>>>,
}

impl MobilePortForward {
    pub fn local_address(&self) -> String {
        self.local_address.clone()
    }

    pub async fn stop(&self) {
        let _ = self.stop.send(true);
        if let Some(task) = self.task.lock().await.take() {
            let _ = task.await;
        }
    }
}

fn bounded_timeout(milliseconds: u64) -> Duration {
    Duration::from_millis(milliseconds.clamp(1_000, 300_000))
}

fn validate_host_and_port(host: &str, port: u16) -> Result<(), String> {
    if host.trim().is_empty() {
        return Err("host must not be empty".to_owned());
    }
    if port == 0 {
        return Err("port must be between 1 and 65535".to_owned());
    }
    Ok(())
}
