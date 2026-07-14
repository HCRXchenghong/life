# Daylink

Daylink 是一个独立实现的 Flutter Android/iOS 应用：把 SSH 运维、持久终端、日程、原生提醒、AI 助手、AI 生图和好友选时间放在同一个产品中。项目不复用 C-SSH 的私有实现或品牌资产。

当前工作代号为 **Daylink**，移动端临时 Bundle ID 为 `app.daylink.daylink_mobile`。正式发布前需要替换为团队拥有域名对应的标识。

## 工程

- `apps/mobile`：Flutter 移动端与原生通知桥接。
- `apps/web`：后台管理、公开投票页、Share API、AI 网关和生成资产服务。
- `crates/mobile-core`：SSH、PTY、端口转发、Agent 事务安装及 Flutter FFI 边界。
- `crates/agent`：Linux 远端 agent。
- `crates/protocol`：客户端、agent 与 Codex bridge 的共享协议。
- `packages/contracts`：HTTP/OpenAPI 与 Agent 协议说明。
- `docs/adr`：关键架构决策。

账号、Microsoft Authenticator 兼容 TOTP、管理员权限边界、端到端加密与多设备实时同步的安全决策见 [ADR-0002](./docs/adr/0002-identity-e2ee-and-sync.md)。

总体开发基线见 [MASTER_PLAN.md](./MASTER_PLAN.md)。
当前实现、验证证据与外部发布门槛见 [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md)。

## 本地验证

```text
cd apps/web && npm ci && npm run test
cd apps/mobile && flutter pub get && flutter test
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

Web 运行环境只需要 `AI_SECRET_MASTER_KEY`（32 字节随机值的 Base64）。它只能通过
本地 `.env` 或托管平台 Secret 注入，不进入仓库。管理员在 `/admin` 登录后配置
第三方 AI Provider、App 登录账号，并按设备签发只显示一次、可撤销的移动 API Token；AI 服务页位于
`/admin/ai`，使用第三方 API 地址、API Key 与模型配置服务。API Key 只写入、不回显；只接受无凭据、
无查询参数的公网 HTTPS Endpoint，且网关
拒绝重定向并隐藏上游错误正文。移动端的 Gateway Base
URL 使用 `https://你的域名/api`，Provider ID 使用后台生成的 ID。

Daylink 的第三方 AI 配置与 Codex 登录是两条独立凭据边界。Codex 能力通过官方 `codex app-server`
协议接入，并支持 Codex 用户级 `model_provider` / `model_providers` 原生配置；自定义 Provider 使用
`base_url`、`env_key` 与 `wire_api = "responses"`。Web 后台保存的第三方 API Key 不会写入 Codex
配置、发送到 SSH 主机或替代 Codex 登录凭据。

安全审计页位于 `/admin/audit`，只展示最近的登录、密码、设备令牌、App 账号和 AI 服务配置事件。
页面查询不会读取审计元数据、目标 ID 或请求 ID；审计写入层也会丢弃敏感字段并限制非可信值长度。

Linux 远端执行 `daylink-agent --stdio` 供 SSH 通道使用，或在设置了
`XDG_RUNTIME_DIR` 后启动 Unix Socket 服务。`DAYLINK_ALLOWED_ROOTS` 使用系统
路径分隔符声明 Agent 可读取和启动 Codex 的目录；未配置时仅允许 `$HOME`。

## 安全基线

- SSH 凭据和移动端 AI Key 只存设备安全保险库。
- Web 托管 AI Key 使用服务端主密钥 AES-GCM 加密，D1 不保存明文。
- 第三方 AI Provider 配置与连接测试仅允许已登录管理员同源调用，并按来源和管理员双因子限流；测试使用固定提示、独立超时且不返回模型输出。
- 安全审计仅对有效管理员会话开放；记录不包含密码、API Key、授权令牌、提示词、用户内容或远程命令输出。
- 管理员登录强制密码与 Microsoft Authenticator TOTP；App 登录使用短期访问令牌和单次轮换刷新令牌，服务端只保存令牌哈希。
- App 内容同步只允许使用服务端会话解析出的 `account_id`；管理员身份域不提供内容读取接口，内容密钥必须由客户端生成和持有。
- 所有 AI 工具调用使用严格 schema、能力白名单、审批和审计。
- Codex 兼容模式通过官方 `codex app-server` 协议接入；不伪造 Codex 内置工具，也不共享 Codex 登录凭据。
