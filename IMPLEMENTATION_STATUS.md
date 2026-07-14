# Daylink 非 UI 实现状态

更新时间：2026-07-14。本文只记录已经进入源码并经过验证的能力。

## 已完成的后端能力

| 领域 | 当前实现 |
| --- | --- |
| Flutter 服务层 | Drift v3、本地 Repository、安全保险库、统一 `DaylinkServices` 容器；Android/iOS 共用领域层 |
| SSH | 密码/私钥认证、严格 known-host/TOFU、命令、PTY、resize、断开、loopback TCP 转发 |
| Linux Agent | CBOR 分帧协议、能力协商、Unix Socket/stdio、目录白名单、文件分块传输与 SHA-256 提交 |
| Agent 安装 | Flutter FFI 上传、64 MiB 上限、本地/远端 SHA-256、远端自检、版本目录和原子 symlink 切换；自检失败不替换旧版本 |
| C-SSH 运维覆盖 | 主机/分组/标签、终端、tmux、文件、指标、进程、firewall、systemd、journal、Docker、批量命令、传输任务、端口转发 |
| 日程提醒 | 手动/AI/投票来源、重复规则、DST、Android exact/inexact、iOS 通知窗口、完成、snooze、启动/恢复对账 |
| AI | 本地 Provider/API Key、Web 托管 Provider、Responses 工具循环、生图、递归 schema 校验、风险审批与敏感输出脱敏 |
| Codex | 官方 App Server JSON-RPC 字段、SSH Agent transport、消息泵、动态工具能力、审批/MCP elicitation 默认拒绝 |
| 好友选时间 | App 创建/刷新/定稿、公开网页投票、匿名编辑令牌、乐观锁、管理令牌安全存储、定稿导入日程 |
| Web 后台 | 管理员密码 + Microsoft TOTP、生产初始化身份白名单、极简概览与 App 账号页、Provider AES-GCM、设备 Token 哈希/撤销、D1/R2、AI 测试、生图、审计、投票管理 |
| App 账号鉴权 | 强密码与独立 pepper 域、15 分钟访问令牌、30 天单次轮换刷新令牌、首次改密、5 次失败锁定、管理员启停/重置即撤销旧会话 |

## 验证证据

- `dart analyze --format=machine`：0 条诊断。
- Flutter：25 项单元/组件测试通过。
- Rust：7 项单元测试通过；workspace Clippy 使用 `-D warnings` 通过。
- Web：ESLint、TypeScript、vinext 生产构建和 3 项黑盒 SSR/health 测试通过。
- Android：debug APK 含 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三套 `libdaylink_mobile_core.so`，并检出 Agent 安装 FFI 符号。
- iOS：模拟器 Runner 与 Rust framework 均为 `arm64 + x86_64`，并检出 Agent 安装 FFI 符号。
- Agent：`--self-test` 返回 agent 版本与协议版本 1。

本地产物：

- Android：`apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`
- iOS 模拟器：`apps/mobile/build/ios/iphonesimulator/Runner.app`

## 需要外部条件的发布门槛

这些不是可在当前无账号、无设备、无服务器凭据环境中伪造完成的代码项：

- Apple/Google 正式签名、Provisioning Profile、商店资料和审核。
- Android/iPhone 真机通知权限、Doze、重启和系统升级矩阵。
- 真实 Linux 主机上的发行版/架构 Agent 包、SSH 断网恢复和 Docker/systemd 权限矩阵。
- 真实 OpenAI/兼容 Provider 计费 Key 的端到端文本与生图调用。
- Web 当前保持 owner-only 私有访问；要让未登录朋友打开投票链接，需要项目所有者明确批准改为公开访问。

## 已知上游迁移提示

- FRB 2.12 Cargokit 仍走 CocoaPods；Flutter 已提示未来需要 Swift Package Manager 支持，当前 iOS 构建成功。
- `flutter_timezone` 当前仍应用 Kotlin Gradle Plugin；Flutter 已提示未来需迁移 Built-in Kotlin，当前 Android 构建成功。

详细 clean-room 调研、功能矩阵、安全模型和发布计划见 `MASTER_PLAN.md`。
