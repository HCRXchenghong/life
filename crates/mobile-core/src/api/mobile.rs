//! Stable Flutter-facing facade. Internal `russh` and protocol types never
//! cross the FFI boundary.

#![forbid(unsafe_code)]
#![allow(unexpected_cfgs)]

use std::net::IpAddr;
use std::sync::Arc;
use std::time::Duration;

use daylink_protocol::{AgentRequest, AgentResponse, Envelope};
use flutter_rust_bridge::frb;
use tokio::net::TcpListener;
use tokio::sync::{Mutex, watch};
use tokio::task::JoinHandle;

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

#[derive(Debug, Clone)]
pub struct BridgeContentKeyInitialization {
    pub device_id: String,
    pub key_version: u32,
    pub recovery_key: Vec<u8>,
    pub recovery_salt: Vec<u8>,
    pub recovery_nonce: Vec<u8>,
    pub recovery_ciphertext: Vec<u8>,
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
