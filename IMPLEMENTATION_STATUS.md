# Daylink 实现状态

更新时间：2026-07-16。本文只记录已经进入源码并经过验证的能力。

## 已完成

| 领域 | 当前实现 |
| --- | --- |
| Flutter 服务层 | Drift v3、按 App 账号隔离的 `app.db`、按账号命名空间隔离的安全保险库、统一 `DaylinkServices` 容器；Android/iOS 共用领域层 |
| Flutter 密文同步接收层 | 按账号增量拉取、严格密文与 nonce 校验、单调游标、幂等本地缓存、SSE 与前台恢复触发；密钥未解锁时不解密或覆盖本机内容 |
| 端到端密钥初始化 | Rust 用系统 CSPRNG 生成 256 位 CMK 与高熵恢复密钥；CMK 只进入设备密钥 AEAD 保护、原子写入且权限为 `0700/0600` 的账号级 `vault.db`，后端只保存 HKDF-SHA256 + AES-256-GCM 恢复密钥信封；并发初始化采用首写胜出且冲突时丢弃本地待确认密钥；Flutter 已实现恢复密钥展示、复制限时清理、后台遮挡和二次确认，确认成功后才清除本地待确认副本 |
| SSH | 密码/私钥认证、严格 known-host/TOFU、命令、PTY、resize、断开、loopback TCP 转发 |
| Linux Agent | CBOR 分帧协议、能力协商、Unix Socket/stdio、目录白名单、文件分块传输与 SHA-256 提交 |
| Agent 安装 | Flutter FFI 上传、64 MiB 上限、本地/远端 SHA-256、远端自检、版本目录和原子 symlink 切换；自检失败不替换旧版本 |
| C-SSH 公共能力覆盖 | 主机/分组/标签、终端、tmux、文件、指标、进程、firewall、systemd、journal、Docker、批量命令、传输任务、端口转发；不复制原项目实现或资产 |
| 日程提醒 | 手动/AI/投票来源、重复规则、DST、Android exact/inexact、iOS 通知窗口、完成、snooze、启动/恢复对账 |
| AI 与 Codex | 本地 AI 与用户 SSH Agent 两种模式共用 Daylink 计费网关；后台配置第三方 API/Key、自动同步模型目录、App 账号独立选模、low/medium/high/xhigh 推理强度、SSE/JSON 兼容、Responses 工具循环、生图、递归 schema 校验、风险审批；官方 Codex App Server JSON-RPC、短期网关凭证、隔离 `CODEX_HOME`、动态工具、审批/MCP elicitation 默认拒绝 |
| Office 文档 | AI 可创建 DOCX、XLSX、PPTX；服务端只接收请求内容并在内存生成 OOXML，App 按账号保存，工具结果不返回设备或服务端路径 |
| 好友选时间 | App 创建/刷新/定稿、公开 React 投票页、匿名编辑令牌、乐观锁、管理令牌安全存储、定稿导入日程 |
| Go 后端 | Go 1.25 HTTP API、MySQL 8.4 内嵌迁移、健康检查、超时/关闭、Caddy 同源反代 |
| Web 后台 | React + Vite；生产初始化口令、首次创建唯一管理员、密码 + Microsoft TOTP、概览/App 账号/安全审计/设置；AI 地址与 Key 已并入设置，独立 AI 页面已移除 |
| App 鉴权 | 强密码、独立 pepper 域、15 分钟访问令牌、30 天单次轮换刷新令牌、首次改密、5 次失败锁定、停用/重置撤销旧会话；停用或管理员重置密码会通过账号隔离 SSE 立即通知 App 清理凭证、关闭账号运行时并返回登录态，数据库复核作为断线兜底；保留管理员手动创建并新增带邀请码的一次性限时邀请 |
| AI 套餐与计费 | 管理员独占 Plus/Pro/Max 发放与取消；周卡/月卡/季度卡/年卡到期；Plus/Pro 以亿 token 配置自然周/月额度，Max 不设用量额度；请求原子预占，最终按上游真实 input/output/total usage 记账并保存缓存与推理明细，失败释放 |
| AI 网关安全 | Provider Key AES-GCM 只写存储；公网 HTTPS、运行时 DNS 私网阻断、防重定向、固定测试、限流、上游错误正文隔离、PNG 校验；SSH 主机仅获 12 小时内且受套餐到期约束的哈希短期凭证 |
| 密文同步服务 | 服务端仅存账号隔离的密文、nonce 和版本头；乐观 revision、幂等 operation ID、追加变更日志、增量游标、SSE 唤醒；管理员没有同步读取路由 |
| 独立部署 | Sites/Worker/Next/D1/R2 代码已移除；Docker Compose 提供 MySQL、Go API、Caddy/React；API/Web 根文件系统只读、丢弃全部 capabilities、无宿主机目录或 Docker Socket；用户 SSH Agent 与部署服务器隔离 |

## 本轮验证证据

- Go：`gofmt`、`go test ./...`、`go vet ./...` 通过。
- React：ESLint、TypeScript、Vite 生产构建与独立部署测试通过，npm audit 为 0。
- Flutter：`flutter analyze` 0 条诊断，94 项测试通过，Android debug APK 与 iOS Simulator debug 构建通过。
- Rust：`cargo fmt --all --check`、workspace Clippy `-D warnings`、11 项测试全部通过。
- 容器：Go 与 React 镜像构建成功；MySQL、API 均健康，Caddy 在局域网 HTTPS 端口运行；API/Web 只读与非特权标志已复验。
- 黑盒：真实 Caddy → Go → MySQL 链路验证错误初始化口令拒绝、管理员初始化、Microsoft TOTP、同源保护、App 双账号、刷新令牌重放拒绝、跨账号密文隔离、管理员无法读取同步内容、投票和公开投票页；实时会话黑盒证明后台停用会在 2 秒门槛内推送 `account_disabled` 并同步撤销数据库会话。

## 尚未声称完成的边界

- Flutter 已接入账号级增量密文拉取和恢复密钥展示/确认，Rust `vault.db` 已实现 CMK/恢复密钥初始化，服务端已实现账号隔离的恢复密钥信封。受信设备批准、新设备解锁、加密出站队列及解密落库仍未接入，因此不能把“新设备自动恢复全部历史内容”标记为端到端交付。
- 管理员能够管理登录身份，但不能恢复用户内容。若所有受信设备和恢复密钥都丢失，旧密文按设计不可恢复。
- 本轮提供的临时第三方凭据对标准 Bearer `/v1/models` 请求返回 HTTP 401，未写入源码、数据库、部署环境或日志；正式联调需要上游可接受的有效 Key。

## 外部发布门槛

- 正式服务器、域名、TLS、备份目标、监控告警与 Secret 管理系统。
- Apple/Google 正式签名、Provisioning Profile、商店资料和审核。
- Android/iPhone 真机通知权限、Doze、重启和系统升级矩阵。
- 真实 Linux 主机上的发行版/架构 Agent 包、SSH 断网恢复和 Docker/systemd 权限矩阵。
- iOS 不承诺持续运行后台 SSH socket 或本地端口转发。

详细 clean-room 调研、功能矩阵、安全模型和发布计划见 `MASTER_PLAN.md`。
