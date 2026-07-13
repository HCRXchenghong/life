# ADR-0001：Daylink 产品与 AI 架构

- 状态：Accepted
- 日期：2026-07-13

## 决策

1. Flutter/Dart 是移动应用、领域用例和日程提醒的主工程。
2. Rust 只承担 SSH/PTY/转发/保险库/agent 协议等原生能力，并通过窄 FFI 暴露。
3. 后台 Web 和好友投票使用 Sites/Worker、D1 与 R2；管理路由使用托管的 ChatGPT 登录身份。
4. AI 分为三条明确通道：
   - Daylink Assistant：OpenAI Responses API 或可配置兼容 Endpoint，负责日程与受控运维工具。
   - Image Generation：Responses API `image_generation` 工具或兼容 Images API。
   - Codex Workspace：连接用户自己机器上的官方 `codex app-server`，保留原生线程、MCP、skills、审批和事件语义。
5. 工具兼容采用 Codex 风格的 `ToolSpec`、严格 JSON Schema、风险等级、批准策略、沙箱边界和审计事件，但 Daylink 工具使用独立命名空间，避免冒充 Codex 内置工具。

## 原因

Responses API 适合多轮、工具和生图；Codex app-server 是深度嵌入 Codex 客户端能力的官方接口。二者认证、运行环境与安全边界不同，混成一个“万能代理”会造成凭据泄漏和审批绕过。

## 后果

- Web 托管环境不能直接运行本地 Codex app-server；Codex 模式必须通过 SSH 到用户控制的主机或用户显式配置的 TLS WebSocket。
- 生图产物存 R2，元数据和权限存 D1。
- API Key 只能在设备保险库或服务器端加密封装中解密使用，永不返回给浏览器。

