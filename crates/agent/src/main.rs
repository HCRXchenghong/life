#![cfg_attr(not(unix), allow(dead_code, unused_imports))]

#[cfg(not(unix))]
compile_error!("daylink-agent currently supports Unix-like remote hosts only");

use std::collections::HashMap;
use std::ffi::OsStr;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result, anyhow, bail};
use bytes::BytesMut;
use daylink_protocol::{
    AgentCapability, AgentError, AgentErrorCode, AgentRequest, AgentResponse, CodexJsonRpcMessage,
    Envelope, EnvelopeKind, FrameCodec, PROTOCOL_VERSION,
};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::io::{
    AsyncBufReadExt, AsyncRead, AsyncReadExt, AsyncSeekExt, AsyncWrite, AsyncWriteExt, BufReader,
};
use tokio::net::UnixListener;
use tokio::process::{Child, ChildStdin, Command};
use tokio::sync::{Mutex, mpsc};
use tracing::{info, warn};
use uuid::Uuid;

const AGENT_VERSION: &str = env!("CARGO_PKG_VERSION");
const MAX_FILE_LIST_ENTRIES: usize = 5_000;
const MAX_FILE_CHUNK_BYTES: u32 = 1024 * 1024;
const MAX_COMMAND_OUTPUT_BYTES: usize = 4 * 1024 * 1024;

#[derive(Clone)]
struct AgentState {
    allowed_roots: Arc<Vec<PathBuf>>,
    transfer_root: Arc<PathBuf>,
    codex_sessions: Arc<Mutex<HashMap<Uuid, CodexProcess>>>,
}

struct CodexProcess {
    child: Child,
    stdin: ChildStdin,
    messages: mpsc::Receiver<CodexJsonRpcMessage>,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "daylink_agent=info".into()),
        )
        .with_writer(std::io::stderr)
        .init();

    let arguments = std::env::args_os().skip(1).collect::<Vec<_>>();
    if arguments.iter().any(|argument| argument == "--version") {
        println!("daylink-agent {AGENT_VERSION} protocol {PROTOCOL_VERSION}");
        return Ok(());
    }
    if arguments.iter().any(|argument| argument == "--self-test") {
        println!(
            "{}",
            json!({
                "ok": true,
                "agentVersion": AGENT_VERSION,
                "protocolVersion": PROTOCOL_VERSION,
            })
        );
        return Ok(());
    }

    let allowed_roots = resolve_allowed_roots()?;
    let transfer_root = allowed_roots[0].join(".daylink/transfers");
    tokio::fs::create_dir_all(&transfer_root).await?;
    set_owner_only_directory_permissions(&transfer_root)?;
    let state = AgentState {
        allowed_roots: Arc::new(allowed_roots),
        transfer_root: Arc::new(transfer_root),
        codex_sessions: Arc::new(Mutex::new(HashMap::new())),
    };
    if arguments.iter().any(|argument| argument == "--stdio") {
        let stdin = tokio::io::stdin();
        let stdout = tokio::io::stdout();
        return serve_stream(stdin, stdout, state).await;
    }

    let socket = match argument_value(&arguments, "--socket") {
        Some(path) => PathBuf::from(path),
        None => default_socket_path()?,
    };
    serve_socket(&socket, state).await
}

fn argument_value<'a>(arguments: &'a [std::ffi::OsString], name: &str) -> Option<&'a OsStr> {
    arguments
        .windows(2)
        .find(|pair| pair[0] == name)
        .map(|pair| pair[1].as_os_str())
}

fn default_socket_path() -> Result<PathBuf> {
    let runtime = std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .ok_or_else(|| anyhow!("XDG_RUNTIME_DIR is required unless --stdio or --socket is used"))?;
    Ok(runtime.join("daylink-agent.sock"))
}

async fn serve_socket(socket: &Path, state: AgentState) -> Result<()> {
    if socket.exists() {
        bail!("refusing to replace existing socket: {}", socket.display());
    }
    let listener =
        UnixListener::bind(socket).with_context(|| format!("bind {}", socket.display()))?;
    set_owner_only_permissions(socket)?;
    info!(path = %socket.display(), "agent socket ready");
    loop {
        let (stream, _) = listener.accept().await?;
        let state = state.clone();
        tokio::spawn(async move {
            let (reader, writer) = stream.into_split();
            if let Err(error) = serve_stream(reader, writer, state).await {
                warn!(%error, "agent connection ended");
            }
        });
    }
}

#[cfg(unix)]
fn set_owner_only_permissions(path: &Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    Ok(())
}

#[cfg(unix)]
fn set_owner_only_directory_permissions(path: &Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o700))?;
    Ok(())
}

async fn serve_stream<R, W>(mut reader: R, mut writer: W, state: AgentState) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    let mut buffer = BytesMut::with_capacity(16 * 1024);
    loop {
        let request = loop {
            if let Some(request) = FrameCodec::decode::<Envelope<AgentRequest>>(&mut buffer)
                .map_err(|error| anyhow!(error))?
            {
                break request;
            }
            if reader.read_buf(&mut buffer).await? == 0 {
                return Ok(());
            }
        };

        let response = if request.protocol_version == PROTOCOL_VERSION {
            match handle_request(request.payload, &state).await {
                Ok(response) => response,
                Err(error) => {
                    warn!(%error, "request failed");
                    AgentResponse::Error(agent_error(
                        AgentErrorCode::RemoteFailure,
                        error.to_string(),
                        false,
                    ))
                }
            }
        } else {
            AgentResponse::Error(agent_error(
                AgentErrorCode::ProtocolMismatch,
                format!(
                    "client protocol {} is incompatible with agent protocol {PROTOCOL_VERSION}",
                    request.protocol_version
                ),
                false,
            ))
        };
        let response = Envelope::new(EnvelopeKind::Response, now_unix_ms(), response)
            .with_request_id(request.request_id);
        let frame = FrameCodec::encode(&response).map_err(|error| anyhow!(error))?;
        writer.write_all(&frame).await?;
        writer.flush().await?;
    }
}

#[allow(clippy::too_many_lines)] // Exhaustive protocol dispatcher; work lives in bounded helpers.
async fn handle_request(request: AgentRequest, state: &AgentState) -> Result<AgentResponse> {
    match request {
        AgentRequest::Hello { .. } => Ok(AgentResponse::Hello {
            agent_version: AGENT_VERSION.to_owned(),
            protocol_version: PROTOCOL_VERSION,
            capabilities: capabilities(),
        }),
        AgentRequest::Ping => Ok(AgentResponse::Pong),
        AgentRequest::SystemInfo => Ok(AgentResponse::Data {
            value: system_info(),
        }),
        AgentRequest::MetricsSnapshot => Ok(AgentResponse::Data {
            value: metrics_snapshot(),
        }),
        AgentRequest::TmuxList => Ok(AgentResponse::Data {
            value: tmux_list().await?,
        }),
        AgentRequest::TmuxCapture {
            session,
            window,
            lines,
        } => Ok(AgentResponse::Data {
            value: tmux_capture(&session, window.as_deref(), lines).await?,
        }),
        AgentRequest::FileList { path } => Ok(AgentResponse::Data {
            value: file_list(state, &path).await?,
        }),
        AgentRequest::FileStat { path } => Ok(AgentResponse::Data {
            value: file_stat(state, &path).await?,
        }),
        AgentRequest::FileRead {
            path,
            offset,
            length,
        } => file_read(state, &path, offset, length).await,
        AgentRequest::FileWriteChunk {
            transfer_id,
            offset,
            data,
        } => Ok(AgentResponse::Data {
            value: file_write_chunk(state, &transfer_id, offset, &data).await?,
        }),
        AgentRequest::FileCommit {
            transfer_id,
            path,
            expected_size,
            expected_sha256,
            overwrite,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: file_commit(
                state,
                &transfer_id,
                &path,
                expected_size,
                &expected_sha256,
                overwrite,
                &approval_id,
            )
            .await?,
        }),
        AgentRequest::FileDelete {
            path,
            recursive,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: file_delete(state, &path, recursive, &approval_id).await?,
        }),
        AgentRequest::FileMove {
            source,
            destination,
            overwrite,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: file_move(state, &source, &destination, overwrite, &approval_id).await?,
        }),
        AgentRequest::FileMkdir {
            path,
            recursive,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: file_mkdir(state, &path, recursive, &approval_id).await?,
        }),
        AgentRequest::CommandRun {
            argv,
            cwd,
            timeout_ms,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: command_run(state, argv, &cwd, timeout_ms, &approval_id).await?,
        }),
        AgentRequest::ProcessList => Ok(AgentResponse::Data {
            value: process_list().await?,
        }),
        AgentRequest::ProcessSignal {
            pid,
            signal,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: process_signal(pid, &signal, &approval_id).await?,
        }),
        AgentRequest::FirewallStatus => Ok(AgentResponse::Data {
            value: firewall_status().await,
        }),
        AgentRequest::SystemdList { user } => Ok(AgentResponse::Data {
            value: systemd_list(user).await?,
        }),
        AgentRequest::SystemdAction {
            unit,
            action,
            user,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: systemd_action(&unit, &action, user, &approval_id).await?,
        }),
        AgentRequest::JournalLogs { unit, user, lines } => Ok(AgentResponse::Data {
            value: journal_logs(&unit, user, lines).await?,
        }),
        AgentRequest::DockerPs => Ok(AgentResponse::Data {
            value: docker_ps().await?,
        }),
        AgentRequest::DockerImages => Ok(AgentResponse::Data {
            value: docker_images().await?,
        }),
        AgentRequest::DockerAction {
            resource,
            action,
            approval_id,
        } => Ok(AgentResponse::Data {
            value: docker_action(&resource, &action, &approval_id).await?,
        }),
        AgentRequest::DockerLogs { container, lines } => Ok(AgentResponse::Data {
            value: docker_logs(&container, lines).await?,
        }),
        AgentRequest::CodexStart { config } => {
            let session_id = codex_start(state, &config.cwd).await?;
            Ok(AgentResponse::CodexStarted { session_id })
        }
        AgentRequest::CodexMessage {
            session_id,
            message,
        } => {
            codex_send(state, session_id, message).await?;
            Ok(AgentResponse::Data {
                value: json!({ "accepted": true }),
            })
        }
        AgentRequest::CodexNextEvent {
            session_id,
            timeout_ms,
        } => Ok(AgentResponse::Data {
            value: codex_next(state, session_id, timeout_ms).await?,
        }),
        AgentRequest::CodexStop { session_id } => {
            codex_stop(state, session_id).await?;
            Ok(AgentResponse::Data {
                value: json!({ "stopped": true }),
            })
        }
        AgentRequest::ToolCall(call) => Ok(AgentResponse::Error(agent_error(
            AgentErrorCode::ApprovalRequired,
            format!("tool '{}' requires the mobile approval pipeline", call.name),
            false,
        ))),
    }
}

fn capabilities() -> Vec<AgentCapability> {
    vec![
        AgentCapability::Tmux,
        AgentCapability::FileRead,
        AgentCapability::FileWrite,
        AgentCapability::FileTransfer,
        AgentCapability::Metrics,
        AgentCapability::Process,
        AgentCapability::Firewall,
        AgentCapability::Systemd,
        AgentCapability::Docker,
        AgentCapability::CodexBridge,
    ]
}

fn resolve_allowed_roots() -> Result<Vec<PathBuf>> {
    let configured = std::env::var_os("DAYLINK_ALLOWED_ROOTS").map(|value| {
        std::env::split_paths(&value)
            .filter(|path| !path.as_os_str().is_empty())
            .collect::<Vec<_>>()
    });
    let roots = match configured {
        Some(roots) if !roots.is_empty() => roots,
        _ => vec![PathBuf::from(
            std::env::var_os("HOME").ok_or_else(|| anyhow!("HOME is not set"))?,
        )],
    };
    roots
        .into_iter()
        .map(|root| {
            root.canonicalize()
                .with_context(|| format!("invalid allowed root {}", root.display()))
        })
        .collect()
}

fn checked_path(state: &AgentState, raw: &str) -> Result<PathBuf> {
    let canonical = Path::new(raw)
        .canonicalize()
        .with_context(|| format!("cannot access {raw}"))?;
    if state
        .allowed_roots
        .iter()
        .any(|root| canonical.starts_with(root))
    {
        Ok(canonical)
    } else {
        bail!("path is outside DAYLINK_ALLOWED_ROOTS")
    }
}

async fn file_list(state: &AgentState, raw: &str) -> Result<Value> {
    let path = checked_path(state, raw)?;
    let mut directory = tokio::fs::read_dir(&path).await?;
    let mut entries = Vec::new();
    while let Some(entry) = directory.next_entry().await? {
        if entries.len() >= MAX_FILE_LIST_ENTRIES {
            bail!("directory contains more than {MAX_FILE_LIST_ENTRIES} entries");
        }
        let metadata = entry.metadata().await?;
        entries.push(json!({
            "name": entry.file_name().to_string_lossy(),
            "path": entry.path(),
            "kind": if metadata.is_dir() { "directory" } else if metadata.is_file() { "file" } else { "other" },
            "bytes": metadata.len(),
            "modifiedUnixMs": metadata.modified().ok().and_then(system_time_ms),
        }));
    }
    entries.sort_by(|left, right| {
        left["name"]
            .as_str()
            .unwrap_or_default()
            .cmp(right["name"].as_str().unwrap_or_default())
    });
    Ok(json!({ "path": path, "entries": entries }))
}

async fn file_stat(state: &AgentState, raw: &str) -> Result<Value> {
    let path = checked_path(state, raw)?;
    let metadata = tokio::fs::metadata(&path).await?;
    Ok(json!({
        "path": path,
        "kind": if metadata.is_dir() { "directory" } else if metadata.is_file() { "file" } else { "other" },
        "bytes": metadata.len(),
        "modifiedUnixMs": metadata.modified().ok().and_then(system_time_ms),
        "readOnly": metadata.permissions().readonly(),
    }))
}

async fn file_read(
    state: &AgentState,
    raw: &str,
    offset: u64,
    length: u32,
) -> Result<AgentResponse> {
    let path = checked_path(state, raw)?;
    let metadata = tokio::fs::metadata(&path).await?;
    if !metadata.is_file() {
        bail!("path is not a regular file")
    }
    let requested = length.clamp(1, MAX_FILE_CHUNK_BYTES) as usize;
    let mut file = tokio::fs::File::open(path).await?;
    file.seek(std::io::SeekFrom::Start(offset)).await?;
    let mut data = vec![0; requested];
    let read = file.read(&mut data).await?;
    data.truncate(read);
    Ok(AgentResponse::FileChunk {
        offset,
        eof: offset.saturating_add(read as u64) >= metadata.len(),
        data,
    })
}

fn transfer_path(state: &AgentState, transfer_id: &str) -> Result<PathBuf> {
    if transfer_id.is_empty()
        || transfer_id.len() > 64
        || !transfer_id
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_')
    {
        bail!("invalid transfer id")
    }
    Ok(state.transfer_root.join(format!("{transfer_id}.part")))
}

async fn file_write_chunk(
    state: &AgentState,
    transfer_id: &str,
    offset: u64,
    data: &[u8],
) -> Result<Value> {
    if data.is_empty() || data.len() > MAX_FILE_CHUNK_BYTES as usize {
        bail!("file chunk must contain 1 to {MAX_FILE_CHUNK_BYTES} bytes")
    }
    if offset.saturating_add(data.len() as u64) > 8 * 1024 * 1024 * 1024 {
        bail!("transfer exceeds the 8 GiB safety limit")
    }
    let path = transfer_path(state, transfer_id)?;
    let mut options = tokio::fs::OpenOptions::new();
    options.create(true).read(true).write(true);
    let mut file = options.open(path).await?;
    let current = file.metadata().await?.len();
    if current != offset {
        bail!("chunk offset mismatch: remote={current}, requested={offset}")
    }
    file.seek(std::io::SeekFrom::Start(offset)).await?;
    file.write_all(data).await?;
    file.flush().await?;
    Ok(json!({ "transferId": transfer_id, "nextOffset": offset + data.len() as u64 }))
}

#[allow(clippy::too_many_arguments)]
async fn file_commit(
    state: &AgentState,
    transfer_id: &str,
    raw_destination: &str,
    expected_size: u64,
    expected_sha256: &str,
    overwrite: bool,
    approval_id: &str,
) -> Result<Value> {
    require_approval(approval_id)?;
    if expected_sha256.len() != 64 || !expected_sha256.bytes().all(|byte| byte.is_ascii_hexdigit())
    {
        bail!("expected SHA-256 must be 64 hexadecimal characters")
    }
    let source = transfer_path(state, transfer_id)?;
    let destination = checked_new_path(state, raw_destination)?;
    if destination.exists() && !overwrite {
        bail!("destination exists and overwrite was not approved")
    }
    let metadata = tokio::fs::metadata(&source).await?;
    if metadata.len() != expected_size {
        bail!(
            "transfer size mismatch: remote={}, expected={expected_size}",
            metadata.len()
        )
    }
    let actual_sha256 = sha256_file(&source).await?;
    if !actual_sha256.eq_ignore_ascii_case(expected_sha256) {
        bail!("transfer SHA-256 mismatch")
    }
    let file = tokio::fs::OpenOptions::new()
        .write(true)
        .open(&source)
        .await?;
    file.sync_all().await?;
    tokio::fs::rename(&source, &destination).await?;
    if let Some(parent) = destination.parent() {
        let directory = tokio::fs::File::open(parent).await?;
        directory.sync_all().await?;
    }
    Ok(json!({
        "path": destination,
        "bytes": expected_size,
        "sha256": actual_sha256,
        "committed": true,
    }))
}

async fn file_delete(
    state: &AgentState,
    raw: &str,
    recursive: bool,
    approval_id: &str,
) -> Result<Value> {
    require_approval(approval_id)?;
    let path = checked_path(state, raw)?;
    if state.allowed_roots.iter().any(|root| root == &path) || path == *state.transfer_root {
        bail!("refusing to delete a protected root")
    }
    let metadata = tokio::fs::symlink_metadata(&path).await?;
    if metadata.is_dir() {
        if recursive {
            tokio::fs::remove_dir_all(&path).await?;
        } else {
            tokio::fs::remove_dir(&path).await?;
        }
    } else {
        tokio::fs::remove_file(&path).await?;
    }
    Ok(json!({ "path": path, "deleted": true }))
}

async fn file_move(
    state: &AgentState,
    raw_source: &str,
    raw_destination: &str,
    overwrite: bool,
    approval_id: &str,
) -> Result<Value> {
    require_approval(approval_id)?;
    let source = checked_path(state, raw_source)?;
    let destination = checked_new_path(state, raw_destination)?;
    if destination.exists() && !overwrite {
        bail!("destination exists and overwrite was not approved")
    }
    tokio::fs::rename(&source, &destination).await?;
    Ok(json!({ "source": source, "destination": destination, "moved": true }))
}

async fn file_mkdir(
    state: &AgentState,
    raw: &str,
    recursive: bool,
    approval_id: &str,
) -> Result<Value> {
    require_approval(approval_id)?;
    let path = checked_new_path(state, raw)?;
    if recursive {
        tokio::fs::create_dir_all(&path).await?;
    } else {
        tokio::fs::create_dir(&path).await?;
    }
    Ok(json!({ "path": path, "created": true }))
}

fn checked_new_path(state: &AgentState, raw: &str) -> Result<PathBuf> {
    let candidate = PathBuf::from(raw);
    if !candidate.is_absolute()
        || candidate.components().any(|component| {
            matches!(
                component,
                std::path::Component::ParentDir | std::path::Component::CurDir
            )
        })
    {
        bail!("destination must be an absolute normalized path")
    }
    let mut ancestor = candidate.as_path();
    while !ancestor.exists() {
        ancestor = ancestor
            .parent()
            .ok_or_else(|| anyhow!("destination has no existing parent"))?;
    }
    let canonical_ancestor = ancestor.canonicalize()?;
    if !state
        .allowed_roots
        .iter()
        .any(|root| canonical_ancestor.starts_with(root))
    {
        bail!("destination is outside DAYLINK_ALLOWED_ROOTS")
    }
    Ok(candidate)
}

async fn sha256_file(path: &Path) -> Result<String> {
    let mut file = tokio::fs::File::open(path).await?;
    let mut digest = Sha256::new();
    let mut buffer = vec![0; 1024 * 1024];
    loop {
        let read = file.read(&mut buffer).await?;
        if read == 0 {
            break;
        }
        digest.update(&buffer[..read]);
    }
    Ok(format!("{:x}", digest.finalize()))
}

fn require_approval(approval_id: &str) -> Result<()> {
    if approval_id.is_empty()
        || approval_id.len() > 128
        || !approval_id
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.'))
    {
        bail!("a valid explicit approval id is required")
    }
    Ok(())
}

async fn tmux_list() -> Result<Value> {
    let output = Command::new("tmux")
        .args([
            "list-sessions",
            "-F",
            "#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}",
        ])
        .output()
        .await
        .context("run tmux list-sessions")?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.contains("no server running") || stderr.contains("no sessions") {
            return Ok(json!({ "sessions": [] }));
        }
        bail!("tmux failed: {}", stderr.trim());
    }
    let sessions = String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter_map(|line| {
            let mut fields = line.split('\t');
            Some(json!({
                "name": fields.next()?,
                "windows": fields.next()?.parse::<u32>().ok()?,
                "attached": fields.next()? == "1",
                "createdUnixSeconds": fields.next()?.parse::<u64>().ok()?,
            }))
        })
        .collect::<Vec<_>>();
    Ok(json!({ "sessions": sessions }))
}

async fn tmux_capture(session: &str, window: Option<&str>, lines: u32) -> Result<Value> {
    if session.is_empty() || session.len() > 200 || window.is_some_and(|value| value.len() > 200) {
        bail!("invalid tmux target")
    }
    let target = window.map_or_else(
        || session.to_owned(),
        |window| format!("{session}:{window}"),
    );
    let line_count = lines.clamp(1, 10_000);
    let output = Command::new("tmux")
        .args([
            "capture-pane",
            "-p",
            "-J",
            "-S",
            &format!("-{line_count}"),
            "-t",
            &target,
        ])
        .output()
        .await?;
    if !output.status.success() {
        bail!(
            "tmux capture failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )
    }
    Ok(json!({
        "target": target,
        "content": String::from_utf8_lossy(&output.stdout),
    }))
}

async fn command_run(
    state: &AgentState,
    argv: Vec<String>,
    raw_cwd: &str,
    timeout_ms: u64,
    approval_id: &str,
) -> Result<Value> {
    require_approval(approval_id)?;
    if argv.is_empty()
        || argv.len() > 64
        || argv.iter().any(|argument| {
            argument.is_empty() || argument.len() > 4_096 || argument.contains('\0')
        })
    {
        bail!("argv must contain 1 to 64 bounded arguments")
    }
    let cwd = checked_path(state, raw_cwd)?;
    if !cwd.is_dir() {
        bail!("command cwd is not a directory")
    }
    let mut command = Command::new(&argv[0]);
    command.args(&argv[1..]).current_dir(cwd).kill_on_drop(true);
    let timeout = Duration::from_millis(timeout_ms.clamp(1, 120_000));
    let output = tokio::time::timeout(timeout, command.output())
        .await
        .map_err(|_| anyhow!("command timed out"))??;
    if output.stdout.len().saturating_add(output.stderr.len()) > MAX_COMMAND_OUTPUT_BYTES {
        bail!("command output exceeded the 4 MiB limit")
    }
    Ok(json!({
        "argv": argv,
        "exitCode": output.status.code(),
        "success": output.status.success(),
        "stdout": String::from_utf8_lossy(&output.stdout),
        "stderr": String::from_utf8_lossy(&output.stderr),
    }))
}

async fn process_list() -> Result<Value> {
    let output = Command::new("ps")
        .args([
            "-eo",
            "pid=,ppid=,user=,stat=,%cpu=,%mem=,comm=",
            "--sort=-%cpu",
        ])
        .output()
        .await?;
    if !output.status.success() {
        bail!(
            "ps failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )
    }
    let processes = String::from_utf8_lossy(&output.stdout)
        .lines()
        .take(10_000)
        .filter_map(|line| {
            let fields = line.split_whitespace().collect::<Vec<_>>();
            if fields.len() < 7 {
                return None;
            }
            Some(json!({
                "pid": fields[0].parse::<u32>().ok()?,
                "parentPid": fields[1].parse::<u32>().ok()?,
                "user": fields[2],
                "state": fields[3],
                "cpuPercent": fields[4].parse::<f64>().ok(),
                "memoryPercent": fields[5].parse::<f64>().ok(),
                "command": fields[6..].join(" "),
            }))
        })
        .collect::<Vec<_>>();
    Ok(json!({ "processes": processes }))
}

async fn process_signal(pid: u32, signal: &str, approval_id: &str) -> Result<Value> {
    require_approval(approval_id)?;
    if pid <= 1 || pid == std::process::id() {
        bail!("refusing to signal a protected process")
    }
    let normalized = signal.to_ascii_uppercase();
    if !matches!(normalized.as_str(), "TERM" | "KILL" | "HUP" | "INT") {
        bail!("unsupported process signal")
    }
    let output = Command::new("kill")
        .args([format!("-{normalized}"), pid.to_string()])
        .output()
        .await?;
    command_success(&output, "kill")?;
    Ok(json!({ "pid": pid, "signal": normalized, "sent": true }))
}

async fn firewall_status() -> Value {
    for (program, arguments) in [
        ("ufw", vec!["status", "verbose"]),
        ("firewall-cmd", vec!["--list-all"]),
        ("nft", vec!["list", "ruleset"]),
    ] {
        if let Ok(output) = Command::new(program).args(arguments).output().await
            && output.status.success()
        {
            return json!({
                "backend": program,
                "output": String::from_utf8_lossy(&output.stdout),
            });
        }
    }
    json!({ "backend": null, "output": "", "available": false })
}

async fn systemd_list(user: bool) -> Result<Value> {
    let mut command = Command::new("systemctl");
    if user {
        command.arg("--user");
    }
    let output = command
        .args([
            "list-units",
            "--type=service",
            "--all",
            "--no-legend",
            "--no-pager",
        ])
        .output()
        .await?;
    command_success(&output, "systemctl list-units")?;
    let units = String::from_utf8_lossy(&output.stdout)
        .lines()
        .take(10_000)
        .filter_map(|line| {
            let fields = line.split_whitespace().collect::<Vec<_>>();
            if fields.len() < 4 {
                return None;
            }
            Some(json!({
                "unit": fields[0],
                "load": fields[1],
                "active": fields[2],
                "sub": fields[3],
                "description": fields.get(4..).unwrap_or_default().join(" "),
            }))
        })
        .collect::<Vec<_>>();
    Ok(json!({ "scope": if user { "user" } else { "system" }, "units": units }))
}

async fn systemd_action(unit: &str, action: &str, user: bool, approval_id: &str) -> Result<Value> {
    require_approval(approval_id)?;
    validate_unit(unit)?;
    if !matches!(action, "start" | "stop" | "restart" | "enable" | "disable") {
        bail!("unsupported systemd action")
    }
    let mut command = Command::new("systemctl");
    if user {
        command.arg("--user");
    }
    let output = command.args([action, unit]).output().await?;
    command_success(&output, "systemctl action")?;
    Ok(json!({ "unit": unit, "action": action, "scope": if user { "user" } else { "system" } }))
}

async fn journal_logs(unit: &str, user: bool, lines: u32) -> Result<Value> {
    validate_unit(unit)?;
    let mut command = Command::new("journalctl");
    if user {
        command.arg("--user");
    }
    let output = command
        .args([
            "-u",
            unit,
            "--no-pager",
            "-n",
            &lines.clamp(1, 10_000).to_string(),
        ])
        .output()
        .await?;
    command_success(&output, "journalctl")?;
    Ok(json!({ "unit": unit, "content": String::from_utf8_lossy(&output.stdout) }))
}

fn validate_unit(unit: &str) -> Result<()> {
    if !unit.ends_with(".service")
        || unit.len() > 256
        || !unit
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'@' | b'-'))
    {
        bail!("invalid systemd service unit")
    }
    Ok(())
}

async fn docker_ps() -> Result<Value> {
    docker_json_lines(
        &["ps", "-a", "--no-trunc", "--format", "{{json .}}"],
        "containers",
    )
    .await
}

async fn docker_images() -> Result<Value> {
    docker_json_lines(
        &["image", "ls", "--no-trunc", "--format", "{{json .}}"],
        "images",
    )
    .await
}

async fn docker_json_lines(arguments: &[&str], field: &str) -> Result<Value> {
    let output = Command::new("docker").args(arguments).output().await?;
    command_success(&output, "docker")?;
    let records = String::from_utf8_lossy(&output.stdout)
        .lines()
        .take(10_000)
        .filter_map(|line| serde_json::from_str::<Value>(line).ok())
        .collect::<Vec<_>>();
    let mut result = serde_json::Map::new();
    result.insert(field.to_owned(), Value::Array(records));
    Ok(Value::Object(result))
}

async fn docker_action(resource: &str, action: &str, approval_id: &str) -> Result<Value> {
    require_approval(approval_id)?;
    validate_resource_id(resource)?;
    let arguments = match action {
        "start" | "stop" | "restart" | "pause" | "unpause" => {
            vec![action.to_owned(), resource.to_owned()]
        }
        "remove_container" => vec!["rm".to_owned(), resource.to_owned()],
        "remove_image" => vec!["image".to_owned(), "rm".to_owned(), resource.to_owned()],
        _ => bail!("unsupported Docker action"),
    };
    let output = Command::new("docker").args(&arguments).output().await?;
    command_success(&output, "docker action")?;
    Ok(json!({ "resource": resource, "action": action, "completed": true }))
}

async fn docker_logs(container: &str, lines: u32) -> Result<Value> {
    validate_resource_id(container)?;
    let output = Command::new("docker")
        .args([
            "logs",
            "--tail",
            &lines.clamp(1, 10_000).to_string(),
            container,
        ])
        .output()
        .await?;
    command_success(&output, "docker logs")?;
    Ok(json!({
        "container": container,
        "stdout": String::from_utf8_lossy(&output.stdout),
        "stderr": String::from_utf8_lossy(&output.stderr),
    }))
}

fn validate_resource_id(value: &str) -> Result<()> {
    if value.is_empty()
        || value.len() > 256
        || value.starts_with('-')
        || !value.bytes().all(|byte| {
            byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'/' | b':' | b'@' | b'-')
        })
    {
        bail!("invalid Docker resource identifier")
    }
    Ok(())
}

fn command_success(output: &std::process::Output, operation: &str) -> Result<()> {
    if output.status.success() {
        Ok(())
    } else {
        bail!(
            "{operation} failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )
    }
}

fn system_info() -> Value {
    let os_release = std::fs::read_to_string("/etc/os-release").unwrap_or_default();
    let fields = os_release
        .lines()
        .filter_map(|line| line.split_once('='))
        .map(|(key, value)| (key.to_owned(), value.trim_matches('"').to_owned()))
        .collect::<HashMap<_, _>>();
    json!({
        "hostname": std::fs::read_to_string("/etc/hostname").unwrap_or_default().trim(),
        "os": fields.get("PRETTY_NAME").or(fields.get("NAME")),
        "kernel": command_text("uname", &["-srmo"]),
        "architecture": std::env::consts::ARCH,
        "agentVersion": AGENT_VERSION,
    })
}

fn metrics_snapshot() -> Value {
    let load = std::fs::read_to_string("/proc/loadavg").unwrap_or_default();
    let uptime = std::fs::read_to_string("/proc/uptime")
        .ok()
        .and_then(|value| value.split_whitespace().next()?.parse::<f64>().ok());
    let memory = parse_meminfo();
    json!({
        "loadAverage": load.split_whitespace().take(3).collect::<Vec<_>>(),
        "uptimeSeconds": uptime,
        "memoryKiB": memory,
        "capturedAtUnixMs": now_unix_ms(),
    })
}

fn parse_meminfo() -> HashMap<String, u64> {
    std::fs::read_to_string("/proc/meminfo")
        .unwrap_or_default()
        .lines()
        .filter_map(|line| {
            let (key, value) = line.split_once(':')?;
            let amount = value.split_whitespace().next()?.parse().ok()?;
            Some((key.to_owned(), amount))
        })
        .collect()
}

fn command_text(program: &str, arguments: &[&str]) -> Option<String> {
    std::process::Command::new(program)
        .args(arguments)
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

async fn codex_start(state: &AgentState, cwd: &str) -> Result<Uuid> {
    let cwd = checked_path(state, cwd)?;
    if !cwd.is_dir() {
        bail!("Codex cwd is not a directory")
    }
    let mut child = Command::new("codex")
        .arg("app-server")
        .current_dir(cwd)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .context("start codex app-server")?;
    let stdin = child.stdin.take().context("Codex stdin unavailable")?;
    let stdout = child.stdout.take().context("Codex stdout unavailable")?;
    let stderr = child.stderr.take().context("Codex stderr unavailable")?;
    let (sender, receiver) = mpsc::channel(256);
    tokio::spawn(async move {
        let mut lines = BufReader::new(stdout).lines();
        loop {
            match lines.next_line().await {
                Ok(Some(line)) => match serde_json::from_str::<CodexJsonRpcMessage>(&line) {
                    Ok(message) => {
                        if sender.send(message).await.is_err() {
                            break;
                        }
                    }
                    Err(error) => warn!(%error, "invalid Codex app-server message"),
                },
                Ok(None) => break,
                Err(error) => {
                    warn!(%error, "Codex stdout failed");
                    break;
                }
            }
        }
    });
    tokio::spawn(async move {
        let mut lines = BufReader::new(stderr).lines();
        while let Ok(Some(line)) = lines.next_line().await {
            warn!(message = %line, "Codex app-server stderr");
        }
    });
    let session_id = Uuid::new_v4();
    state.codex_sessions.lock().await.insert(
        session_id,
        CodexProcess {
            child,
            stdin,
            messages: receiver,
        },
    );
    Ok(session_id)
}

async fn codex_send(
    state: &AgentState,
    session_id: Uuid,
    message: CodexJsonRpcMessage,
) -> Result<()> {
    let mut sessions = state.codex_sessions.lock().await;
    let process = sessions
        .get_mut(&session_id)
        .ok_or_else(|| anyhow!("Codex session not found"))?;
    let mut encoded = serde_json::to_vec(&message)?;
    encoded.push(b'\n');
    process.stdin.write_all(&encoded).await?;
    process.stdin.flush().await?;
    Ok(())
}

async fn codex_next(state: &AgentState, session_id: Uuid, timeout_ms: u64) -> Result<Value> {
    let mut sessions = state.codex_sessions.lock().await;
    let process = sessions
        .get_mut(&session_id)
        .ok_or_else(|| anyhow!("Codex session not found"))?;
    let timeout = Duration::from_millis(timeout_ms.clamp(1, 60_000));
    match tokio::time::timeout(timeout, process.messages.recv()).await {
        Ok(Some(message)) => Ok(serde_json::to_value(message)?),
        Ok(None) => bail!("Codex app-server closed"),
        Err(_) => Ok(json!({ "timeout": true })),
    }
}

async fn codex_stop(state: &AgentState, session_id: Uuid) -> Result<()> {
    let mut process = state
        .codex_sessions
        .lock()
        .await
        .remove(&session_id)
        .ok_or_else(|| anyhow!("Codex session not found"))?;
    process.child.kill().await?;
    let _status = process.child.wait().await?;
    Ok(())
}

fn agent_error(code: AgentErrorCode, message: String, retryable: bool) -> AgentError {
    AgentError {
        code,
        message,
        retryable,
        sensitive: false,
    }
}

fn system_time_ms(time: SystemTime) -> Option<u128> {
    time.duration_since(UNIX_EPOCH)
        .ok()
        .map(|value| value.as_millis())
}

fn now_unix_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .ok()
        .and_then(|value| i64::try_from(value.as_millis()).ok())
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn test_state() -> (AgentState, PathBuf) {
        let root = std::env::temp_dir().join(format!("daylink-agent-test-{}", Uuid::new_v4()));
        let transfer_root = root.join(".daylink/transfers");
        tokio::fs::create_dir_all(&transfer_root)
            .await
            .expect("create test dirs");
        (
            AgentState {
                allowed_roots: Arc::new(vec![root.canonicalize().expect("canonical root")]),
                transfer_root: Arc::new(transfer_root),
                codex_sessions: Arc::new(Mutex::new(HashMap::new())),
            },
            root,
        )
    }

    #[tokio::test]
    async fn chunked_upload_commits_only_after_size_and_hash_match() {
        let (state, root) = test_state().await;
        file_write_chunk(&state, "transfer-1", 0, b"hel")
            .await
            .expect("first chunk");
        file_write_chunk(&state, "transfer-1", 3, b"lo")
            .await
            .expect("second chunk");
        let destination = root.join("hello.txt");
        file_commit(
            &state,
            "transfer-1",
            destination.to_str().expect("path"),
            5,
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
            false,
            "approval-test",
        )
        .await
        .expect("commit");

        assert_eq!(tokio::fs::read(&destination).await.expect("read"), b"hello");
        assert!(!state.transfer_root.join("transfer-1.part").exists());
        tokio::fs::remove_dir_all(root).await.expect("cleanup");
    }

    #[tokio::test]
    async fn upload_rejects_out_of_order_chunks() {
        let (state, root) = test_state().await;
        let error = file_write_chunk(&state, "transfer-2", 10, b"wrong")
            .await
            .expect_err("offset must fail");
        assert!(error.to_string().contains("offset mismatch"));
        tokio::fs::remove_dir_all(root).await.expect("cleanup");
    }

    #[tokio::test]
    async fn write_paths_are_normalized_and_root_bounded() {
        let (state, root) = test_state().await;
        let traversal = format!("{}/nested/../escape", root.display());
        assert!(checked_new_path(&state, &traversal).is_err());
        assert!(require_approval("").is_err());
        assert!(require_approval("approved-123").is_ok());
        tokio::fs::remove_dir_all(root).await.expect("cleanup");
    }
}
