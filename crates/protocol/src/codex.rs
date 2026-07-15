use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::{ApprovalPolicy, SandboxMode};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CodexThreadConfig {
    pub cwd: String,
    pub model: Option<String>,
    #[serde(default)]
    pub reasoning_effort: Option<String>,
    pub approval_policy: ApprovalPolicy,
    pub sandbox: SandboxMode,
    pub service_name: String,
    #[serde(default)]
    pub gateway_base_url: Option<String>,
    #[serde(default)]
    pub gateway_token: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum CodexJsonRpcMessage {
    Request {
        id: Value,
        method: String,
        #[serde(default)]
        params: Value,
    },
    Notification {
        method: String,
        #[serde(default)]
        params: Value,
    },
    Response {
        id: Value,
        #[serde(skip_serializing_if = "Option::is_none")]
        result: Option<Value>,
        #[serde(skip_serializing_if = "Option::is_none")]
        error: Option<Value>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CodexApprovalKind {
    CommandExecution,
    FileChange,
    Permission,
    McpTool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CodexApprovalRequest {
    pub approval_id: Uuid,
    pub thread_id: String,
    pub turn_id: Option<String>,
    pub kind: CodexApprovalKind,
    pub reason: Option<String>,
    pub details: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CodexApprovalDecision {
    Accept,
    AcceptForSession,
    Decline,
    Cancel,
}
