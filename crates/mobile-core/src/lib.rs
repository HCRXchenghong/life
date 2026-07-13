//! Native SSH transport for the Flutter application.
//!
//! Unknown host keys are deliberately rejected. Call [`probe_host_key`] first,
//! show the fingerprint to the user, persist their decision, then connect with
//! the accepted fingerprint.

#![deny(unsafe_code)]

pub mod api;
#[allow(unsafe_code, clippy::all, clippy::pedantic)]
mod frb_generated;

use std::fmt::Write as _;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use bytes::BytesMut;
use daylink_protocol::{AgentRequest, AgentResponse, Envelope, EnvelopeKind, FrameCodec};
use russh::client;
use russh::keys::ssh_key;
use russh::keys::{PrivateKeyWithHashAlg, decode_secret_key};
use russh::{ChannelMsg, Disconnect};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use uuid::Uuid;

const MAX_AGENT_BINARY_BYTES: usize = 64 * 1024 * 1024;
const AGENT_INSTALL_SCRIPT: &str = r#"set -eu
id=$1
version=$2
expected=$3
base="$HOME/.local/lib/daylink-agent"
stage="$base/staging/$id"
dest="$base/versions/$version"
tmp="$dest.new-$id"
linktmp="$HOME/.local/bin/.daylink-agent-$id"
cleanup() { rm -f "$stage" "$tmp" "$linktmp"; }
trap cleanup EXIT HUP INT TERM
actual=$(sha256sum "$stage" | awk '{print $1}')
[ "$actual" = "$expected" ] || { echo "agent sha256 mismatch" >&2; exit 41; }
chmod 700 "$stage"
"$stage" --self-test >/dev/null
mkdir -p "$base/versions" "$HOME/.local/bin"
mv "$stage" "$tmp"
mv -f "$tmp" "$dest"
ln -s "$dest" "$linktmp"
mv -f "$linktmp" "$HOME/.local/bin/daylink-agent"
trap - EXIT HUP INT TERM
"$HOME/.local/bin/daylink-agent" --version
"#;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostKey {
    pub algorithm: String,
    pub fingerprint_sha256: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConnectionConfig {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub accepted_host_key_sha256: String,
    pub connect_timeout: Duration,
    pub inactivity_timeout: Duration,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Authentication {
    Password(String),
    PrivateKey {
        pem: String,
        passphrase: Option<String>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CommandOutput {
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub exit_status: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentInstallResult {
    pub version: String,
    pub remote_path: String,
    pub sha256: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TerminalEvent {
    Stdout(Vec<u8>),
    Stderr(Vec<u8>),
    Exit(u32),
    Closed,
}

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("SSH transport failed: {0}")]
    Ssh(#[from] russh::Error),
    #[error("SSH key could not be decoded: {0}")]
    Key(String),
    #[error("authentication was rejected")]
    AuthenticationRejected,
    #[error("host key was not observed")]
    HostKeyUnavailable,
    #[error("host key mismatch (expected {expected}, received {received})")]
    HostKeyMismatch { expected: String, received: String },
    #[error("connection timed out")]
    Timeout,
    #[error("I/O failed: {0}")]
    Io(#[from] std::io::Error),
    #[error("agent frame failed: {0}")]
    Frame(String),
    #[error("agent closed the channel")]
    AgentClosed,
    #[error("agent installation failed: {0}")]
    AgentInstall(String),
}

#[derive(Clone)]
struct StrictHostKeyHandler {
    expected: Option<String>,
    observed: Arc<Mutex<Option<HostKey>>>,
}

impl client::Handler for StrictHostKeyHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        server_public_key: &ssh_key::PublicKey,
    ) -> Result<bool, Self::Error> {
        let host_key = HostKey {
            algorithm: server_public_key.algorithm().to_string(),
            fingerprint_sha256: server_public_key
                .fingerprint(ssh_key::HashAlg::Sha256)
                .to_string(),
        };
        let accepted = self.expected.as_ref() == Some(&host_key.fingerprint_sha256);
        *self.observed.lock().expect("host key mutex poisoned") = Some(host_key);
        Ok(accepted)
    }
}

/// Reads the remote fingerprint without trusting it or authenticating.
pub async fn probe_host_key(
    host: &str,
    port: u16,
    timeout: Duration,
) -> Result<HostKey, CoreError> {
    let observed = Arc::new(Mutex::new(None));
    let handler = StrictHostKeyHandler {
        expected: None,
        observed: Arc::clone(&observed),
    };
    let config = Arc::new(client::Config {
        inactivity_timeout: Some(timeout),
        ..Default::default()
    });
    let result =
        tokio::time::timeout(timeout, client::connect(config, (host, port), handler)).await;
    if result.is_err() {
        return Err(CoreError::Timeout);
    }
    let key = observed
        .lock()
        .expect("host key mutex poisoned")
        .clone()
        .ok_or(CoreError::HostKeyUnavailable)?;
    Ok(key)
}

pub struct SshSession {
    handle: client::Handle<StrictHostKeyHandler>,
}

impl SshSession {
    pub async fn connect(
        config: &ConnectionConfig,
        authentication: Authentication,
    ) -> Result<Self, CoreError> {
        let observed = Arc::new(Mutex::new(None));
        let handler = StrictHostKeyHandler {
            expected: Some(config.accepted_host_key_sha256.clone()),
            observed: Arc::clone(&observed),
        };
        let client_config = Arc::new(client::Config {
            inactivity_timeout: Some(config.inactivity_timeout),
            nodelay: true,
            ..Default::default()
        });
        let connection = tokio::time::timeout(
            config.connect_timeout,
            client::connect(client_config, (config.host.as_str(), config.port), handler),
        )
        .await
        .map_err(|_| CoreError::Timeout)?;

        if let Some(received) = observed
            .lock()
            .expect("host key mutex poisoned")
            .as_ref()
            .map(|key| key.fingerprint_sha256.clone())
            && received != config.accepted_host_key_sha256
        {
            return Err(CoreError::HostKeyMismatch {
                expected: config.accepted_host_key_sha256.clone(),
                received,
            });
        }
        let mut handle = connection?;

        let auth_result = match authentication {
            Authentication::Password(password) => {
                handle
                    .authenticate_password(&config.username, password)
                    .await?
            }
            Authentication::PrivateKey { pem, passphrase } => {
                let private_key = decode_secret_key(&pem, passphrase.as_deref())
                    .map_err(|error| CoreError::Key(error.to_string()))?;
                let hash = handle.best_supported_rsa_hash().await?.flatten();
                handle
                    .authenticate_publickey(
                        &config.username,
                        PrivateKeyWithHashAlg::new(Arc::new(private_key), hash),
                    )
                    .await?
            }
        };
        if !auth_result.success() {
            return Err(CoreError::AuthenticationRejected);
        }
        Ok(Self { handle })
    }

    pub async fn execute(&self, command: &str) -> Result<CommandOutput, CoreError> {
        self.execute_with_input(command, &[]).await
    }

    async fn execute_with_input(
        &self,
        command: &str,
        input: &[u8],
    ) -> Result<CommandOutput, CoreError> {
        let mut channel = self.handle.channel_open_session().await?;
        channel.exec(true, command.as_bytes()).await?;
        for chunk in input.chunks(32 * 1024) {
            channel.data_bytes(chunk.to_vec()).await?;
        }
        channel.eof().await?;
        let mut output = CommandOutput {
            stdout: Vec::new(),
            stderr: Vec::new(),
            exit_status: None,
        };
        while let Some(message) = channel.wait().await {
            match message {
                ChannelMsg::Data { data } => output.stdout.extend_from_slice(&data),
                ChannelMsg::ExtendedData { data, .. } => output.stderr.extend_from_slice(&data),
                ChannelMsg::ExitStatus { exit_status } => output.exit_status = Some(exit_status),
                _ => {}
            }
        }
        Ok(output)
    }

    pub async fn install_agent(
        &self,
        binary: &[u8],
        version: &str,
        expected_sha256: &str,
    ) -> Result<AgentInstallResult, CoreError> {
        validate_agent_release(binary, version, expected_sha256)?;
        let actual_sha256 = sha256_hex(binary);
        if actual_sha256 != expected_sha256.to_ascii_lowercase() {
            return Err(CoreError::AgentInstall(
                "local agent binary does not match expected sha256".to_owned(),
            ));
        }
        let staging_id = Uuid::new_v4().simple().to_string();
        let upload = format!(
            "sh -c 'umask 077; mkdir -p \"$HOME/.local/lib/daylink-agent/staging\"; cat > \"$HOME/.local/lib/daylink-agent/staging/{staging_id}\"'"
        );
        let uploaded = self.execute_with_input(&upload, binary).await?;
        if uploaded.exit_status != Some(0) {
            return Err(CoreError::AgentInstall(format!(
                "agent upload failed: {}",
                String::from_utf8_lossy(&uploaded.stderr).trim()
            )));
        }
        let activate = format!(
            "sh -s -- {staging_id} {version} {}",
            expected_sha256.to_ascii_lowercase()
        );
        let activated = self
            .execute_with_input(&activate, AGENT_INSTALL_SCRIPT.as_bytes())
            .await?;
        if activated.exit_status != Some(0) {
            return Err(CoreError::AgentInstall(format!(
                "agent activation failed: {}",
                String::from_utf8_lossy(&activated.stderr).trim()
            )));
        }
        Ok(AgentInstallResult {
            version: version.to_owned(),
            remote_path: format!("~/.local/lib/daylink-agent/versions/{version}"),
            sha256: actual_sha256,
        })
    }

    pub async fn open_terminal(
        &self,
        term: &str,
        columns: u32,
        rows: u32,
    ) -> Result<PtySession, CoreError> {
        let channel = self.handle.channel_open_session().await?;
        channel
            .request_pty(false, term, columns, rows, 0, 0, &[])
            .await?;
        channel.request_shell(true).await?;
        Ok(PtySession { channel })
    }

    pub async fn open_agent(&self) -> Result<AgentChannel, CoreError> {
        let channel = self.handle.channel_open_session().await?;
        channel
            .exec(
                true,
                br#"if command -v daylink-agent >/dev/null 2>&1; then exec daylink-agent --stdio; else exec "$HOME/.local/bin/daylink-agent" --stdio; fi"#,
            )
            .await?;
        Ok(AgentChannel {
            stream: channel.into_stream(),
            receive_buffer: BytesMut::new(),
        })
    }

    pub async fn forward_stream<T>(
        &self,
        mut local: T,
        remote_host: &str,
        remote_port: u16,
        originator_host: &str,
        originator_port: u16,
    ) -> Result<(u64, u64), CoreError>
    where
        T: AsyncRead + AsyncWrite + Unpin,
    {
        let channel = self
            .handle
            .channel_open_direct_tcpip(
                remote_host,
                u32::from(remote_port),
                originator_host,
                u32::from(originator_port),
            )
            .await?;
        let mut remote = channel.into_stream();
        Ok(tokio::io::copy_bidirectional(&mut local, &mut remote).await?)
    }

    pub async fn disconnect(&self) -> Result<(), CoreError> {
        self.handle
            .disconnect(Disconnect::ByApplication, "Daylink disconnect", "en")
            .await?;
        Ok(())
    }
}

fn validate_agent_release(
    binary: &[u8],
    version: &str,
    expected_sha256: &str,
) -> Result<(), CoreError> {
    if binary.is_empty() || binary.len() > MAX_AGENT_BINARY_BYTES {
        return Err(CoreError::AgentInstall(
            "agent binary must contain 1 byte to 64 MiB".to_owned(),
        ));
    }
    if version.is_empty()
        || version.len() > 64
        || !version
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
    {
        return Err(CoreError::AgentInstall("invalid agent version".to_owned()));
    }
    if expected_sha256.len() != 64 || !expected_sha256.bytes().all(|byte| byte.is_ascii_hexdigit())
    {
        return Err(CoreError::AgentInstall(
            "expected sha256 must contain 64 hexadecimal characters".to_owned(),
        ));
    }
    Ok(())
}

fn sha256_hex(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    let mut output = String::with_capacity(digest.len() * 2);
    for byte in digest {
        write!(&mut output, "{byte:02x}").expect("writing to a String cannot fail");
    }
    output
}

pub struct PtySession {
    channel: russh::Channel<client::Msg>,
}

impl PtySession {
    pub async fn write(&self, data: &[u8]) -> Result<(), CoreError> {
        self.channel.data_bytes(data.to_vec()).await?;
        Ok(())
    }

    pub async fn resize(&self, columns: u32, rows: u32) -> Result<(), CoreError> {
        self.channel.window_change(columns, rows, 0, 0).await?;
        Ok(())
    }

    pub async fn next_event(&mut self) -> TerminalEvent {
        loop {
            match self.channel.wait().await {
                Some(ChannelMsg::Data { data }) => return TerminalEvent::Stdout(data.to_vec()),
                Some(ChannelMsg::ExtendedData { data, .. }) => {
                    return TerminalEvent::Stderr(data.to_vec());
                }
                Some(ChannelMsg::ExitStatus { exit_status }) => {
                    return TerminalEvent::Exit(exit_status);
                }
                Some(_) => {}
                None => return TerminalEvent::Closed,
            }
        }
    }

    pub async fn close(&self) -> Result<(), CoreError> {
        self.channel.eof().await?;
        self.channel.close().await?;
        Ok(())
    }
}

pub struct AgentChannel {
    stream: russh::ChannelStream<client::Msg>,
    receive_buffer: BytesMut,
}

impl AgentChannel {
    pub async fn request(
        &mut self,
        sent_at_unix_ms: i64,
        request: AgentRequest,
    ) -> Result<Envelope<AgentResponse>, CoreError> {
        let envelope = Envelope::new(EnvelopeKind::Request, sent_at_unix_ms, request);
        let request_id = envelope.request_id;
        let frame =
            FrameCodec::encode(&envelope).map_err(|error| CoreError::Frame(error.to_string()))?;
        self.stream.write_all(&frame).await?;
        self.stream.flush().await?;
        loop {
            if let Some(response) =
                FrameCodec::decode::<Envelope<AgentResponse>>(&mut self.receive_buffer)
                    .map_err(|error| CoreError::Frame(error.to_string()))?
                && response.request_id == request_id
            {
                return Ok(response);
            }
            let read = self.stream.read_buf(&mut self.receive_buffer).await?;
            if read == 0 {
                return Err(CoreError::AgentClosed);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use russh::client::Handler;

    #[tokio::test]
    async fn unknown_key_handler_records_but_rejects_key() {
        let public = russh::keys::ssh_key::PublicKey::from_openssh(
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdD7y3aLq454yWBdwLWbieU1ebz9/cu7/QEXn9OIeZJ",
        )
        .expect("public key");
        let observed = Arc::new(Mutex::new(None));
        let mut handler = StrictHostKeyHandler {
            expected: None,
            observed: Arc::clone(&observed),
        };
        assert!(!handler.check_server_key(&public).await.expect("check"));
        assert!(observed.lock().expect("mutex").is_some());
    }

    #[test]
    fn agent_release_validation_rejects_injection_and_hash_mismatch() {
        assert!(validate_agent_release(b"binary", "1.2.3", &"a".repeat(64)).is_ok());
        assert!(validate_agent_release(b"binary", "1.2.3; rm -rf /", &"a".repeat(64)).is_err());
        assert!(validate_agent_release(b"binary", "1.2.3", "not-a-hash").is_err());
    }

    #[test]
    fn sha256_is_lowercase_and_stable() {
        assert_eq!(
            sha256_hex(b"daylink"),
            "4024f38485b7957e83908f92b20d5e7b457e7de169fa530bd389240aa23bed3f"
        );
    }
}
