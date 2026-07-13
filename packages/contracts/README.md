# Daylink contracts

- `openapi.yaml`：Web、移动端 AI Gateway 和好友时间投票的 HTTP 契约。
- Rust Agent 二进制协议以 `crates/protocol` 的 Serde 类型为唯一事实源：4 字节大端长度 + CBOR，单帧最大 8 MiB，`protocol_version=1`。
- Codex 通道只传递官方 app-server 的 JSONL/JSON-RPC 消息；Daylink 不改写审批请求，也不会把拒绝默认值改成允许。

任何破坏兼容性的改动必须提升 HTTP 主版本或 Agent `PROTOCOL_VERSION`，并同时提供迁移与兼容测试。
