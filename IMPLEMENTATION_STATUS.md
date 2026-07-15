# Daylink 实现状态

更新时间：2026-07-15。本文只记录已经进入源码并经过验证的能力。

## 已完成

| 领域 | 当前实现 |
| --- | --- |
| Flutter 服务层 | Drift v3、本地 Repository、安全保险库、统一 `DaylinkServices` 容器；Android/iOS 共用领域层 |
| SSH | 密码/私钥认证、严格 known-host/TOFU、命令、PTY、resize、断开、loopback TCP 转发 |
| Linux Agent | CBOR 分帧协议、能力协商、Unix Socket/stdio、目录白名单、文件分块传输与 SHA-256 提交 |
| Agent 安装 | Flutter FFI 上传、64 MiB 上限、本地/远端 SHA-256、远端自检、版本目录和原子 symlink 切换；自检失败不替换旧版本 |
| C-SSH 公共能力覆盖 | 主机/分组/标签、终端、tmux、文件、指标、进程、firewall、systemd、journal、Docker、批量命令、传输任务、端口转发；不复制原项目实现或资产 |
| 日程提醒 | 手动/AI/投票来源、重复规则、DST、Android exact/inexact、iOS 通知窗口、完成、snooze、启动/恢复对账 |
| AI 与 Codex | 本地第三方 API/Key、服务端第三方 Provider、Responses 工具循环、生图、递归 schema 校验、风险审批；官方 Codex App Server JSON-RPC、SSH Agent transport、动态工具、审批/MCP elicitation 默认拒绝 |
| 好友选时间 | App 创建/刷新/定稿、公开 React 投票页、匿名编辑令牌、乐观锁、管理令牌安全存储、定稿导入日程 |
| Go 后端 | Go 1.25 HTTP API、MySQL 8.4 内嵌迁移、健康检查、超时/关闭、Caddy 同源反代 |
| Web 后台 | React + Vite；生产初始化口令、首次创建唯一管理员、密码 + Microsoft TOTP、概览/App 账号/AI 服务/安全审计/设置；管理员改密和 TOTP 重绑二次验证 |
| App 鉴权 | 强密码、独立 pepper 域、15 分钟访问令牌、30 天单次轮换刷新令牌、首次改密、5 次失败锁定、停用/重置撤销旧会话 |
| AI 网关安全 | Provider Key AES-GCM 只写存储；公网 HTTPS、运行时 DNS 私网阻断、防重定向、固定测试、限流、上游错误正文隔离、PNG 校验 |
| 密文同步服务 | 服务端仅存账号隔离的密文、nonce 和版本头；乐观 revision、幂等 operation ID、追加变更日志、增量游标、SSE 唤醒；管理员没有同步读取路由 |
| 独立部署 | Sites/Worker/Next/D1/R2 代码已移除；Docker Compose 提供 MySQL、Go API、Caddy/React，生成图片使用受限本地持久卷 |

## 本轮验证证据

- Go：`gofmt`、`go test ./...`、`go vet ./...` 通过。
- React：ESLint、TypeScript、Vite 生产构建与独立部署测试通过，npm audit 为 0。
- Flutter：39 个 Dart 文件格式无变化，`flutter analyze` 0 条诊断，25 项测试通过。Flutter 3.44 的 analysis server 在中文绝对路径上会截断 LSP JSON，本轮在同源码的 ASCII 临时副本复验通过。
- Rust：`cargo fmt --all --check`、workspace Clippy `-D warnings`、7 项测试全部通过。
- 容器：Go 与 React 镜像构建成功；MySQL 8.4 真实启动并完成全部初始迁移。
- 黑盒：真实 Caddy → Go → MySQL 链路验证错误初始化口令拒绝、管理员初始化、Microsoft TOTP、同源保护、App 双账号、刷新令牌重放拒绝、跨账号密文隔离、管理员无法读取同步内容、投票和公开投票页。

## 尚未声称完成的边界

- 服务端密文同步协议已经落地，但 Flutter 端 CMK 生成/封装、受信设备批准、恢复密钥和同步队列尚未接入，因此不能把“新设备自动恢复全部历史内容”标记为端到端交付。
- 管理员能够管理登录身份，但不能恢复用户内容。若所有受信设备和恢复密钥都丢失，旧密文按设计不可恢复。
- 真实第三方 Responses/Images Provider 仍需要有效计费 Key 做端到端验证；当前只完成协议、校验、存储和安全网关测试。

## 外部发布门槛

- 正式服务器、域名、TLS、备份目标、监控告警与 Secret 管理系统。
- Apple/Google 正式签名、Provisioning Profile、商店资料和审核。
- Android/iPhone 真机通知权限、Doze、重启和系统升级矩阵。
- 真实 Linux 主机上的发行版/架构 Agent 包、SSH 断网恢复和 Docker/systemd 权限矩阵。
- iOS 不承诺持续运行后台 SSH socket 或本地端口转发。

详细 clean-room 调研、功能矩阵、安全模型和发布计划见 `MASTER_PLAN.md`。
