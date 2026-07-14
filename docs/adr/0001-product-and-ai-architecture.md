# ADR-0001：Daylink 产品与 AI 架构

- 状态：Accepted
- 日期：2026-07-13

## 决策

1. Flutter/Dart 是移动应用、领域用例和日程提醒的主工程。
2. Rust 只承担 SSH/PTY/转发/保险库/agent 协议等原生能力，并通过窄 FFI 暴露。
3. 后台 Web 和好友投票使用 Sites/Worker、D1 与 R2；管理路由使用托管的 ChatGPT 登录身份。
4. AI 分为三条明确通道：
   - Daylink Assistant：可配置的第三方 Responses 兼容 API，使用 API 地址与 API Key，负责日程与受控运维工具。
   - Image Generation：第三方兼容 Images API。
   - Codex Workspace：连接用户自己机器上的官方 `codex app-server`，保留原生线程、MCP、skills、审批和事件语义。
5. 工具兼容采用 Codex 风格的 `ToolSpec`、严格 JSON Schema、风险等级、批准策略、沙箱边界和审计事件，但 Daylink 工具使用独立命名空间，避免冒充 Codex 内置工具。

## 原因

Responses API 适合多轮、工具和生图；Codex app-server 是深度嵌入 Codex 客户端能力的官方接口。二者认证、运行环境与安全边界不同，混成一个“万能代理”会造成凭据泄漏和审批绕过。

第三方 AI Provider 与 Codex 原生配置保持分离：Daylink Assistant 的 Key 由设备保险库或 Web
服务端密钥库保存；Codex app-server 使用远端主机的用户级 Codex 配置。自定义 Codex Provider
通过 `model_provider`、`model_providers.<id>.base_url`、`env_key` 与
`wire_api = "responses"` 配置，Daylink 不把 Web 保存的 Key 写入远端配置或进程参数。

## 后果

- Web 托管环境不能直接运行本地 Codex app-server；Codex 模式必须通过 SSH 到用户控制的主机或用户显式配置的 TLS WebSocket。
- 生图产物存 R2，元数据和权限存 D1。
- API Key 只能在设备保险库或服务器端加密封装中解密使用，永不返回给浏览器。
