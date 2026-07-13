//! Versioned protocol shared by the Flutter native core and the Linux agent.

mod codex;
mod envelope;
mod frame;
mod tool;

pub use codex::{
    CodexApprovalDecision, CodexApprovalKind, CodexApprovalRequest, CodexJsonRpcMessage,
    CodexThreadConfig,
};
pub use envelope::{
    AgentCapability, AgentError, AgentErrorCode, AgentRequest, AgentResponse, Envelope,
    EnvelopeKind, PROTOCOL_VERSION,
};
pub use frame::{FrameCodec, FrameError, MAX_FRAME_BYTES};
pub use tool::{ApprovalPolicy, RiskLevel, SandboxMode, ToolCall, ToolResult, ToolSpec};
