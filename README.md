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
Provider，并按设备签发只显示一次、可撤销的移动 API Token；移动端的 Gateway Base
URL 使用 `https://你的域名/api`，Provider ID 使用后台生成的 ID。

Linux 远端执行 `daylink-agent --stdio` 供 SSH 通道使用，或在设置了
`XDG_RUNTIME_DIR` 后启动 Unix Socket 服务。`DAYLINK_ALLOWED_ROOTS` 使用系统
路径分隔符声明 Agent 可读取和启动 Codex 的目录；未配置时仅允许 `$HOME`。

## 安全基线

- SSH 凭据和移动端 AI Key 只存设备安全保险库。
- Web 托管 AI Key 使用服务端主密钥 AES-GCM 加密，D1 不保存明文。
- 所有 AI 工具调用使用严格 schema、能力白名单、审批和审计。
- Codex 兼容模式通过官方 `codex app-server` 协议接入；不伪造 Codex 内置工具，也不共享 Codex 登录凭据。
