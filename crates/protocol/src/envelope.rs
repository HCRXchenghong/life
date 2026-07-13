use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

pub const PROTOCOL_VERSION: u16 = 1;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EnvelopeKind {
    Request,
    Response,
    Event,
    Cancel,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Envelope<T> {
    pub protocol_version: u16,
    pub request_id: Uuid,
    pub kind: EnvelopeKind,
    pub sent_at_unix_ms: i64,
    pub payload: T,
}

impl<T> Envelope<T> {
    #[must_use]
    pub fn new(kind: EnvelopeKind, sent_at_unix_ms: i64, payload: T) -> Self {
        Self {
            protocol_version: PROTOCOL_VERSION,
            request_id: Uuid::new_v4(),
            kind,
            sent_at_unix_ms,
            payload,
        }
    }

    #[must_use]
    pub fn with_request_id(mut self, request_id: Uuid) -> Self {
        self.request_id = request_id;
        self
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentCapability {
    Tmux,
    FileRead,
    FileWrite,
    FileTransfer,
    Metrics,
    Process,
    Firewall,
    Systemd,
    Docker,
    CodexBridge,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum AgentRequest {
    Hello {
        client_version: String,
        requested_capabilities: Vec<AgentCapability>,
    },
    Ping,
    SystemInfo,
    MetricsSnapshot,
    TmuxList,
    TmuxCapture {
        session: String,
        window: Option<String>,
        lines: u32,
    },
    FileList {
        path: String,
    },
    FileStat {
        path: String,
    },
    FileRead {
        path: String,
        offset: u64,
        length: u32,
    },
    FileWriteChunk {
        transfer_id: String,
        offset: u64,
        data: Vec<u8>,
    },
    FileCommit {
        transfer_id: String,
        path: String,
        expected_size: u64,
        expected_sha256: String,
        overwrite: bool,
        approval_id: String,
    },
    FileDelete {
        path: String,
        recursive: bool,
        approval_id: String,
    },
    FileMove {
        source: String,
        destination: String,
        overwrite: bool,
        approval_id: String,
    },
    FileMkdir {
        path: String,
        recursive: bool,
        approval_id: String,
    },
    CommandRun {
        argv: Vec<String>,
        cwd: String,
        timeout_ms: u64,
        approval_id: String,
    },
    ProcessList,
    ProcessSignal {
        pid: u32,
        signal: String,
        approval_id: String,
    },
    FirewallStatus,
    SystemdList {
        user: bool,
    },
    SystemdAction {
        unit: String,
        action: String,
        user: bool,
        approval_id: String,
    },
    JournalLogs {
        unit: String,
        user: bool,
        lines: u32,
    },
    DockerPs,
    DockerImages,
    DockerAction {
        resource: String,
        action: String,
        approval_id: String,
    },
    DockerLogs {
        container: String,
        lines: u32,
    },
    CodexStart {
        config: crate::CodexThreadConfig,
    },
    CodexMessage {
        session_id: Uuid,
        message: crate::CodexJsonRpcMessage,
    },
    CodexNextEvent {
        session_id: Uuid,
        timeout_ms: u64,
    },
    CodexStop {
        session_id: Uuid,
    },
    ToolCall(crate::ToolCall),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum AgentResponse {
    Hello {
        agent_version: String,
        protocol_version: u16,
        capabilities: Vec<AgentCapability>,
    },
    Pong,
    Data {
        value: Value,
    },
    FileChunk {
        offset: u64,
        data: Vec<u8>,
        eof: bool,
    },
    CodexStarted {
        session_id: Uuid,
    },
    ToolResult(crate::ToolResult),
    Error(AgentError),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentErrorCode {
    BadRequest,
    ProtocolMismatch,
    UnsupportedCapability,
    PermissionDenied,
    ApprovalRequired,
    Conflict,
    Timeout,
    Cancelled,
    NotFound,
    RemoteFailure,
    Internal,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentError {
    pub code: AgentErrorCode,
    pub message: String,
    pub retryable: bool,
    pub sensitive: bool,
}
