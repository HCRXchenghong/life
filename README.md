# Daylink

Daylink 是一个独立实现的 Flutter Android/iOS 应用：把 SSH 运维、持久终端、日程、原生提醒、AI 助手、AI 生图和好友选时间放在同一个产品中。项目遵守 clean-room 边界，不复用 C-SSH 的私有实现、协议、命名或品牌资产。

Web 系统已经从 Sites/Cloudflare 迁出。当前独立部署栈为：

- `apps/api`：Go HTTP API，负责后台鉴权、App 鉴权、AI 网关、投票与密文同步。
- `apps/web`：React + Vite 后台和公开投票页，不包含服务端 Secret。
- `deploy`：MySQL 8.4、Go API、Caddy/React 的 Docker Compose 部署。
- `apps/mobile`：Flutter Android/iOS 客户端与原生通知桥接。
- `crates/mobile-core`：Rust SSH、PTY、端口转发、Agent 安装及 Flutter FFI。
- `crates/agent`：Linux 远端 Agent。
- `crates/protocol`：客户端、Agent 与 Codex bridge 的共享协议。
- `packages/contracts`：HTTP/OpenAPI 与 Agent 协议。

总体计划见 [MASTER_PLAN.md](./MASTER_PLAN.md)，当前交付边界与验证证据见 [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md)。身份、2FA、内容加密和多设备同步的安全决策见 [ADR-0002](./docs/adr/0002-identity-e2ee-and-sync.md)。

## 独立部署

```text
cp deploy/.env.example deploy/.env
# 填写数据库密码、两个 master key 和独立初始化口令，并将 PUBLIC_ORIGIN 改为正式 HTTPS 域名
docker compose --env-file deploy/.env -f deploy/docker-compose.yml up -d --build
```

部署后直接打开 `PUBLIC_ORIGIN/admin`。首次进入时提交部署环境中的一次性初始化口令并创建唯一管理员账号，随后用 Microsoft Authenticator 扫描本地生成的二维码并验证；后续登录必须同时提交管理员密码和不可重放的 TOTP。loopback 开发环境可不设置初始化口令。

App 账号有两种并行创建方式：管理员原有的“账号 + 初始密码”手动创建流程保持不变；也可以生成带独立邀请码的一次性邀请链接，有效期可选 1 天、1 周或 1 月，成功注册一个账号后立即失效。App 本身只提供登录入口，不提供公开注册。

生产环境必须使用 HTTPS。`AUTH_SECRET_MASTER_KEY` 和 `AI_SECRET_MASTER_KEY` 必须分别生成，不得复用。Compose 通过分离的 `MYSQL_*` 变量构造连接配置，随机密码无需手工拼接到 DSN；Secret 只通过部署环境注入，不写入仓库。

## 本地开发

启动 MySQL 后运行 API：

```text
cd apps/api
cp .env.example .env
set -a; source .env; set +a
go run ./cmd/daylink-api
```

另一个终端启动 React：

```text
cd apps/web
npm ci
npm run dev
```

Vite 会把 `/api` 代理到 `127.0.0.1:8080`，后台地址为 `http://localhost:5173/admin`。此时 API 的 `PUBLIC_ORIGIN` 也应设置为 `http://localhost:5173`。

## 安全边界

- 管理后台不使用 GPT/ChatGPT 登录；只使用应用自己的管理员账号、强密码和 Microsoft Authenticator TOTP。
- 管理员和 App 密码使用不同 pepper 域、随机盐与 600,000 次 PBKDF2-SHA256。
- App 使用 15 分钟访问令牌和 30 天一次性轮换刷新令牌；数据库只存令牌哈希。
- 第三方 AI API Key 使用独立主密钥 AES-GCM 加密，只写入、不回显，也不会写入 Codex 配置或发送到 SSH 主机。
- AI 地址和 API Key 只在后台设置页配置；服务会自动识别 Responses 与生图模型。Word、Excel 和 PowerPoint 只使用用户主动提交的结构化内容在内存中生成，响应不包含服务端路径，App 文件按账号保存到设备隔离目录。
- AI 上游只允许无凭据、无查询参数的公网 HTTPS 地址；运行时重新解析 DNS、拒绝私网地址和重定向，错误响应不回传上游正文。
- 用户自行添加的 SSH 主机与 Daylink 部署服务器是两个安全域：前者可在审批、超时、取消和审计规则下使用完整 Agent 工具；后者不提供 Agent/SSH API，不挂载宿主机目录或 Docker Socket，App 用户和 AI 无法读取其文件、目录、日志或终端。
- 同步 API 的账号范围只取自访问令牌，服务端只接收客户端密文、nonce 和最小版本元数据；后台没有内容读取接口。
- 实时通知使用账号隔离的 SSE，断线后以单调游标补拉；写入包含幂等 operation ID 和乐观 revision。
- SSH Secret、API Key、原始授权令牌、私钥和完整远程命令输出不得进入日志或审计。

## 验证

```text
cd apps/api && gofmt -w . && go test ./... && go vet ./...
cd apps/web && npm ci && npm run lint && npm run test
cd apps/mobile && dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

移动端仍保持 Dart 独占 `app.db`、Rust 独占 `vault.db`。iOS 不承诺持续运行后台 SSH socket 或本地端口转发。
