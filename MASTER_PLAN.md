# Flutter 跨平台 SSH + 日程协作 App 总体开发计划

> 2026-07-14 增补：Web 管理员账号/TOTP 2FA、App 多账号隔离、端到端加密和新设备实时同步以 `docs/adr/0002-identity-e2ee-and-sync.md` 为实现基线。管理员可管理登录身份，但不持有用户内容密钥。

> 文档状态：方案基线 v1.0  
> 编制日期：2026-07-13（Asia/Shanghai）  
> 当前范围：只规划并实现非前端 UI；不制作正式页面、视觉系统和交互细节。  
> 目标平台：Android、iOS；远端受管机第一阶段为 Linux x86_64 / aarch64。

## 1. 结论先行

本项目不应尝试“把 C-SSH 改成 Flutter”，也不能以其现有源码为基础，因为公开仓库目前没有源码和开源许可证。正确路线是从零实现一个独立产品：

- Flutter/Dart 是移动 App 的主工程，承载领域模型、用例、数据库、日程、提醒、AI 编排、分享预约及以后全部 UI。
- 独立 Rust Mobile Core 通过 FFI 提供 SSH、SFTP/文件流、PTY、端口转发、加密保险库、远端 agent 协议等底层能力。
- 独立 Rust Linux Agent 常驻远端服务器，提供 tmux 持久会话、监控、结构化文件/系统/Docker/systemd 能力。
- 独立 Share API 支持生成链接、匿名参与、候选时间投票、截止与结果确认；朋友不安装 App 也能通过网页参与。
- 日程是 local-first，系统提醒由 Android AlarmManager/通知与 iOS UserNotifications 实现；个人日程初期不上传云端。
- AI 只通过受控工具修改日程或操作主机，永远不能直写数据库、读取 SSH 密钥或绕过权限确认。

这套架构仍然是“基于 Flutter 的 App”，Rust 只相当于一个跨平台原生插件和远端服务程序，不承担 UI，也不复用 C-SSH 的实现。

## 2. 对 C-SSH 的审阅范围与可信边界

### 2.1 已审阅材料

本计划基于以下公开材料逐项核对：

- `README.md`、`README_EN.md`。
- `CHANGELOG.md`、`CHANGELOG_EN.md`，覆盖 v0.4 至 v0.6.10。
- 仓库内全部桌面端和 Android 截图。
- v0.6.10 Android APK 的 Manifest、资源、原生库及公开符号。
- v0.6.10 Linux deb、桌面二进制、内置 Linux agent 与 tmux 资源的静态结构。
- GitHub Issues 中公开的并发、持久化、终端尺寸、主题和更新诉求。

### 2.2 已确认的项目事实

- 最新公开版本是 v0.6.10，公开仓库在 2026-07-12 更新；仓库网页的部分缓存仍可能显示 v0.6.8。
- 仓库明确声明“当前仅用于简介、截图与安装包分发，iOS/macOS 正式版后再开源”。当前没有可供继承的源代码。
- Android 包名为 `com.creationssh.mobile`，v0.6.10 的 `versionCode=6010`、`minSdk=24`、`targetSdk=36`。
- 当前 Android 客户端是 Tauri 2 + Rust 原生库 + Web 前端，不是 Flutter；Manifest 目前只声明网络权限，没有日程通知能力。
- 客户端使用 Rust SSH 栈、SQLite 本地库、TOFU known-host 校验、本地加密保险库和按主机并发保护。
- 远端 agent 使用长度分帧的结构化协议、Unix socket、tmux 和 redb 指标库；支持 direct-streamlocal 与 stdio bridge 兼容通道。
- agent 以 SSH 登录用户身份工作，不额外提权；系统破坏性操作由客户端二次确认。
- v0.6.10 的部署流程已经包含跨客户端锁、唯一暂存/备份、大小与 SHA256 校验、systemd 单元归属检查、readiness/握手、两阶段回滚以及 tmux 存活保护。

### 2.3 静态核查还原出的主要模块

客户端公开二进制能够确认以下模块边界：

- `client_core`：SSH、known_hosts、密钥兼容、agent 部署、agent 传输、端口转发、保险库。
- `creation_core`：请求/响应协议、文件条目、指标、Docker/systemd/窗口等结构体。
- `ai_agent`：OpenAI 兼容与 Anthropic provider、会话压缩、权限、只读/写入/终端工具组。
- 移动/桌面适配层：主机、部署、终端、监控、文件、系统管理、应用中心、批量命令、授权、AI 运行状态。
- 远端 `agent`：Unix server、tmux、流式命令、Docker、systemd、防火墙、进程、文件和指标采集。

公开二进制中的本地数据结构还确认了 `groups`、`servers`、`tags`、`server_tags`、`secrets`、`known_hosts`、`server_state`、`port_forwards`、`snippets`、`access_grants`、`audit_log`、`metrics_cache`、`collection_prefs`、`ai_conversations`、`ai_audit`、`ai_runs`、`ai_run_events` 等表。

### 2.4 不能声称已知的内容

- 私有源码的具体算法、所有协议字段、完整 UI 状态机和测试代码均不可见。
- 截图包含演示性内容，不能把每个视觉元素当成正式行为规范。
- “永久免费”“未来开源”不等于当前允许复制代码、品牌、图标、截图或协议实现。

因此，本项目只做功能兼容和独立设计，不反编译复制实现，不使用 Creation-SSH/C-SSH 名称与品牌资产。正式发布前必须完成一次商标和许可证审查。

## 3. 产品范围

### 3.1 第一阶段必须交付

1. Android/iOS Flutter 工程骨架和可测试的无 UI 业务核心。
2. 主机、分组、标签、收藏、搜索、凭据、known-host 与 agent 状态管理。
3. 密码和 OpenSSH 私钥登录，Ed25519 优先，RSA/ECDSA 兼容回退。
4. 普通 SSH PTY 与 agent+tmux 持久化终端。
5. 远端 Linux agent 的安装、升级、修复、版本握手和完整回滚。
6. 实时/历史监控、文件管理、端口转发、命令片段和批量执行。
7. 系统信息、进程、防火墙、SSH 密码、Docker、镜像、容器、systemd 服务与日志。
8. AI 对话、工具调用、权限分层、确认、运行持久化、暂停/继续/终止和审计。
9. 本地日程、重复规则、多提醒、稍后提醒、完成/取消、冲突检查。
10. Android/iOS 系统原生本地通知，支持重启、时区变更和权限变化后的对账。
11. AI 自然语言创建/修改/取消日程，提交前输出结构化差异并确认。
12. 生成好友选时间链接；匿名投票、修改投票、截止、选定最终时间并导入本地日程。
13. 全部核心 API、数据库迁移、平台桥接和端到端测试；不做正式页面 UI。

### 3.2 明确不在本阶段

- 正式 App 页面、视觉设计、动画、响应式布局和可访问性精修。
- 桌面端 Windows/macOS/Linux Flutter 客户端。
- 个人日程的多设备云同步。
- 团队 RBAC、企业 SSO、堡垒机、审计合规报表。
- Kubernetes 管理、RDP/VNC、Mosh、VPN。
- 后台持续 SSH 端口转发在 iOS 上的不可实现承诺。
- 自动替用户执行高风险运维且不确认。

## 4. C-SSH 功能覆盖矩阵

| 功能域 | C-SSH 已确认能力 | 本项目非 UI 交付 | 验收重点 |
| --- | --- | --- | --- |
| 主机管理 | 增删改、分组、标签/收藏、搜索、agent 状态 | 完整领域模型、Repository、Rust 连接适配 | 数据迁移、并发编辑、删除级联 |
| SSH 凭据 | 密码、OpenSSH 私钥、本地保险库、认证回退 | 独立保险库和认证策略 | 密钥不进日志/云端，失败分类准确 |
| 主机密钥 | TOFU、变更提示、接受变更 | known_hosts 指纹与显式变更流程 | 首连、重复连、MITM 变更测试 |
| 终端 | 普通 PTY、tmux 持久化、窗口、resize/capture | Rust Stream API、会话恢复状态机 | 断网/杀 App/换设备后恢复远端内容 |
| agent 通道 | streamlocal + stdio bridge | 独立协议和双通道自动回退 | 老 OpenSSH、CentOS/Rocky 兼容 |
| agent 部署 | 上传、锁、校验、systemd/nohup、回滚 | 事务化部署器 | 任意阶段故障不破坏旧 agent/tmux |
| 监控 | CPU/内存/磁盘/网络/IO/Top、实时/历史 | agent 采集和本地缓存 | 采样精度、保留期、离线读取 |
| 文件 | 列表、搜索、编辑、增删改、上传下载、续传 | 分块、校验、临时文件原子提交 | 大文件中断恢复与 SHA256 |
| 端口映射 | SSH local forwarding，默认 127.0.0.1 | 前台转发、Android 可选 FGS | 端口冲突、App 生命周期、LAN 风险 |
| 命令片段 | CRUD、多机批量、分主机结果 | 片段库、运行批次和结果模型 | 超时、取消、部分失败、审计 |
| 系统管理 | 系统信息、进程、防火墙、SSH 改密 | 结构化 agent 请求 | 不额外提权、二次确认、保护自身进程 |
| 应用中心 | Docker 安装、应用部署、容器/镜像/systemd | 可声明应用模板与结构化操作 | 镜像白名单、日志流、破坏操作确认 |
| 访问授权 | 本地保险库、SSH key、一次性授权、AI 审计 | 设备本地授权记录和撤销 | 私钥加密、授权状态、撤销幂等 |
| AI | 双 provider、五档权限、工具循环、上下文、历史 | provider 抽象、工具策略、持久运行 | 提示注入隔离、确认不可绕过 |
| 设置 | 语言、主题、更新、登录门、采集设置 | 非 UI 配置模型与平台服务 | 原子保存、默认值、升级兼容 |
| 日程 | 原项目没有 | 本地日程、重复、提醒、冲突、AI 配置 | DST、时区、重启、权限拒绝 |
| 好友选时间 | 原项目没有 | 分享 API、投票、截止、导入日程 | 链接安全、匿名修改、并发冲突 |

## 5. 不可回避的平台差异

| 能力 | Android | iOS | 产品承诺 |
| --- | --- | --- | --- |
| 本地日程提醒 | 可用；精确提醒需 Alarms & reminders 特殊权限 | 可用；系统在 App 不运行时也可投递 | 两端支持；权限不足时明确标为近似提醒 |
| 通知权限 | Android 13+ 需 `POST_NOTIFICATIONS` | 需 UserNotifications 授权 | 只在用户创建首个提醒时解释并申请 |
| 重启恢复 | 监听 boot 后重建提醒 | 系统保留已提交的 pending request；启动时对账 | 数据库永远是唯一事实源 |
| 待提醒数量 | 厂商可能附加限制 | iOS 只保留最近设置的 64 个 pending 通知 | iOS 采用最近 50 个的滚动窗口 |
| SSH 交互 | 前台可靠 | 前台可靠 | 两端等价 |
| tmux 长任务 | 任务运行在远端 agent/tmux | 任务运行在远端 agent/tmux | App 退出不影响远端任务 |
| 活跃 SSH 网络流 | 可由用户主动启动前台服务延续，但受商店政策和系统限制 | 普通 App 进入后台后会被挂起 | iOS 不承诺后台终端/转发常驻 |
| 本地端口转发 | 默认只在 App 前台；可选显式前台服务 | 仅前台/短暂收尾 | UI 必须显示生命周期和断开原因 |
| SSH 大文件传输 | 前台；可选用户发起的数据传输机制 | 普通 SSH socket 在挂起后不能可靠持续 | 所有传输必须分块、可续传 |
| 实时监控 | App 前台订阅；agent 在服务器持续采集 | App 前台订阅；agent 在服务器持续采集 | 历史连续性由 agent 保证，不依赖手机后台 |

## 6. 总体架构

```text
Flutter App (Dart)
├── Domain / Use cases
├── Repositories / Drift app.db
├── Schedule & Notification Coordinator
├── AI Orchestrator & Tool Policy
├── Share API Client / Deep Links
├── Platform Services (notifications, key wrapping, lifecycle)
└── Rust FFI facade
    └── Mobile Core (Rust)
        ├── SSH / PTY / SFTP / local forwarding
        ├── known_hosts / credential vault
        ├── Agent deployment transaction
        ├── Agent framed protocol
        └── Streaming + concurrency guard

SSH encrypted transport
└── Linux Agent (Rust, musl static)
    ├── Unix socket 0600
    ├── tmux persistence
    ├── metrics.redb
    ├── structured file/system operations
    └── Docker / systemd / firewall / process adapters

HTTPS
└── Share Service
    ├── REST API
    ├── PostgreSQL
    ├── opaque invite/manage tokens
    └── Web fallback (UI later)
```

### 6.1 分层原则

- Flutter 官方推荐的 View/ViewModel/Repository/Service 分层仍保留，但当前不实现 View。
- 复杂跨仓库业务放在 Use Case 层，Repository 不互相依赖。
- Dart 领域层不得依赖 Flutter Widget、平台插件或 Rust 生成类型。
- Rust FFI 只暴露稳定 DTO 和异步 Stream，不泄露 `russh`、Tokio 或内部协议类型。
- 不允许 Dart 和 Rust 同时写同一个 SQLite 文件。
- App 数据根统一由一个 `DataRootResolver` 决定，避免不同平台/模块出现数据库根分裂。

## 7. 建议仓库结构

```text
/
├── apps/
│   └── mobile/                 # Flutter Android/iOS 主工程；目前仅最小壳
├── packages/
│   ├── app_domain/             # 纯 Dart entities/value objects/errors
│   ├── app_usecases/           # 业务用例、事务编排
│   ├── app_data/               # Drift、API client、Repository 实现
│   ├── schedule_engine/        # 时区、重复、occurrence、冲突
│   ├── notification_bridge/    # Flutter + Kotlin/Swift 通知适配
│   ├── ai_orchestrator/        # provider、tool loop、policy、audit
│   └── shared_contracts/       # Dart DTO / JSON schema 生成物
├── native/
│   ├── mobile_core/            # Rust FFI 库
│   ├── mobile_bridge/          # flutter_rust_bridge 生成配置
│   └── platform_keys/          # Kotlin/Swift key wrapping 插件
├── agent/
│   └── linux_agent/            # 独立 Rust workspace / musl targets
├── services/
│   └── share_api/              # Rust Axum + PostgreSQL
├── contracts/
│   ├── agent/                  # 协议 schema、黄金向量
│   ├── share/openapi.yaml
│   └── ai_tools/               # 工具 JSON Schema
├── integration_test/
│   ├── device/
│   ├── ssh_lab/
│   ├── notifications/
│   └── share_api/
├── infra/
│   ├── dev-compose/
│   └── ci/
└── docs/
    ├── adr/
    ├── threat-model/
    ├── protocol/
    └── release/
```

## 8. 技术选型基线

### 8.1 移动端

- Flutter 3.44.0 / Dart 3.12.0（当前本机稳定版）；后续通过 FVM 或等价工具锁定。
- Android：`minSdk 24`，`compileSdk/targetSdk 36`。
- iOS：建议最低 iOS 15.0；若商业目标要求更低，再单独做兼容评估。
- 状态和依赖注入：领域层不绑定框架；UI 阶段再选 Riverpod 或官方推荐方案。
- 本地数据：Drift + SQLite，严格 schema version 和可逆/可验证迁移。
- Rust 桥接：`flutter_rust_bridge`，所有生成物进入 CI 一致性检查。
- 通知：`flutter_local_notifications` 作为高层适配，关键权限、boot、action 和对账逻辑由自有桥接层封装，避免业务直接依赖插件 API。
- 时区：IANA tzdb + `timezone`；重复规则按 RFC 5545 可支持子集实现并保留原始 RRULE。
- Deep Link：HTTPS Universal Links / Android App Links，禁止把自定义 scheme 作为分享链接主路径。

### 8.2 Rust Mobile Core

- Tokio 异步运行时。
- SSH：先做 2 周技术验证，在 `russh` 与维护活跃的替代库之间按 direct-streamlocal、PTY、SFTP、host-key、iOS 交叉编译实测决策。
- 序列化：FFI 使用生成 DTO；agent 线上协议使用长度前缀 + CBOR，配最大帧限制和 schema 版本。
- 加密：系统 CSPRNG；保险库 payload 使用 AEAD（优先 XChaCha20-Poly1305 或 AES-256-GCM），每条记录独立 nonce 和 AAD。
- 哈希：SHA-256 用于文件/部署完整性；Argon2id 仅用于用户自定义本地登录密码派生。

### 8.3 Linux Agent

- Rust + musl 静态链接，首发 `x86_64-unknown-linux-musl` 和 `aarch64-unknown-linux-musl`。
- 支持 user systemd、system systemd（仅已有权限时）和 nohup 兜底。
- tmux 作为独立校验资源部署；版本和架构在握手中报告。
- 指标历史使用 redb；协议状态与临时文件放在统一 `~/.<product>/` 根下。

### 8.4 Share Service

- Rust Axum、PostgreSQL、SQLx，OpenAPI 为契约源。
- TLS 由托管负载均衡/反向代理终止。
- Redis 只在确有速率限制/短期幂等缓存需求时加入，不作为首发硬依赖。
- 服务必须有无状态横向扩容能力；所有写接口支持 Idempotency-Key。

## 9. 本地数据设计

### 9.1 数据库所有权

为避免跨语言并发写损坏，分为两个数据库，但共享唯一数据根：

- `app.db`：由 Dart/Drift 独占；存主机非敏感信息、日程、AI 历史、通知映射和分享状态。
- `vault.db`：由 Rust Core 独占；只存加密后的 SSH 密码、私钥、AI API key、授权私钥。
- `known_hosts` 可以放 `app.db` 的指纹元数据，但接受/验证逻辑由 Rust Core 完成。
- 远端 `metrics.redb` 由 agent 独占；手机只保存有限缓存。

### 9.2 `app.db` 核心表

#### SSH 与运维

- `host_groups(id, name, sort_order, created_at, updated_at)`
- `hosts(id, name, address, port, username, auth_ref, group_id, notes, favorite, terminal_mode, created_at, updated_at, deleted_at)`
- `tags(id, name, color)` / `host_tags(host_id, tag_id)`
- `known_hosts(host_id, algorithm, fingerprint_sha256, first_seen_at, last_seen_at, status)`
- `agent_states(host_id, protocol_version, agent_version, arch, capabilities_json, transport, last_seen_at, health)`
- `port_forwards(id, host_id, bind_address, local_port, target_host, target_port, auto_start, state, last_error)`
- `snippets(id, name, command, tags_json, timeout_seconds, created_at, updated_at)`
- `command_batches(id, snippet_id, command_snapshot, started_at, finished_at, status)`
- `command_results(id, batch_id, host_id, exit_code, stdout_preview, stderr_preview, artifact_ref, status)`
- `monitor_cache(host_id, sampled_at, metrics_json)`
- `collection_prefs(host_id, enabled, interval_seconds, retention_days)`

#### AI

- `ai_provider_profiles(id, kind, base_url, model, context_window, secret_ref, enabled)`
- `ai_conversations(id, host_id, title, revision, created_at, updated_at, deleted_at)`
- `ai_messages(id, conversation_id, role, content_json, sequence)`
- `ai_runs(id, conversation_id, mode, exec_policy, status, started_at, updated_at, final_text)`
- `ai_run_events(id, run_id, sequence, occurred_at, event_json)`
- `ai_audits(id, run_id, host_id, tool, safe_args, decision, result_preview, status, occurred_at)`
- `ai_preferences(id=1, max_tool_calls, performance_profile, context_preferences_json)`

#### 日程与提醒

- `calendars(id, name, color, is_default, created_at, updated_at)`
- `events(id, calendar_id, title, notes, location, start_local, end_local, timezone_id, time_semantics, all_day, status, source, version, created_at, updated_at)`
- `recurrence_rules(event_id, rrule, until_utc, count, exceptions_json)`
- `reminder_rules(id, event_id, offset_seconds, channel, sound, exact_requested, enabled)`
- `event_occurrences(id, event_id, starts_at_utc, ends_at_utc, local_key, status, generated_at)`
- `notification_jobs(id, occurrence_id, reminder_rule_id, platform_id, fire_at_utc, state, scheduled_revision, last_error)`
- `snoozes(id, notification_job_id, fire_at_utc, created_at, status)`
- `schedule_audit(id, event_id, actor, action, before_json, after_json, occurred_at)`

#### 分享预约

- `shared_polls(id, remote_id, invite_url, manage_secret_ref, revision, status, expires_at, last_synced_at)`
- `shared_poll_slots(poll_id, remote_slot_id, starts_at_utc, ends_at_utc, timezone_id)`
- `shared_poll_local_state(poll_id, participant_edit_secret_ref, selected_slot_id, imported_event_id)`
- `sync_outbox(id, aggregate_type, aggregate_id, operation, payload_json, idempotency_key, retry_at, attempts)`

### 9.3 时间模型规则

- 绝不只保存一个 UTC 时间；同时保存原始本地时间、IANA `timezone_id` 和时间语义。
- `wall_clock`：例如“每周一上海时间 9:00”，跨 DST 时保持当地 9:00。
- `fixed_instant`：例如线上发布在一个全球绝对时刻，移动时区后本地显示变化。
- DST 不存在时间返回 `InvalidLocalTime`，不自动偷偷偏移。
- DST 重复时间返回两个候选 instant，要求调用方明确选 earlier/later。
- 重复事件按有限 horizon 物化 occurrence，不能无限预生成。

## 10. 凭据与本地保险库

### 10.1 密钥层级

1. 每台设备生成 256-bit Vault Master Key（VMK）。
2. iOS：VMK 作为 ThisDeviceOnly Keychain item 保存，可选用户在“每次使用/每次解锁”策略中启用生物验证。
3. Android：在 Android Keystore 生成不可导出的 wrapping key，用其加密 VMK；密文保存在 App 私有目录。
4. 每条 secret 使用 VMK 派生的记录 key 加密，AAD 包含 `secret_id + host_id + kind + schema_version`。
5. 数据库只出现密文、nonce、算法和版本，不出现明文、VMK 或可复用 token。

### 10.2 强制规则

- SSH 密码、私钥、AI API key 不进入 Dart 日志、Crash report、analytics 或 Share API。
- 明文只在最短作用域存在；Rust 中使用可清零缓冲区。
- 备份默认不包含 SSH 凭据；iOS Keychain item 与 Android VMK 密文均设为设备绑定。
- 导入私钥先识别 PEM/OpenSSH、加密状态、算法和公钥指纹；加密私钥口令另行处理。
- `.env`、`id_rsa`、`*.key`、证书私钥等默认禁止作为 AI 附件。
- “本地登录门”与系统生物验证不能替代数据库加密，只是额外访问控制。

## 11. SSH 与终端核心

### 11.1 连接状态机

```text
Idle -> Resolving -> TcpConnecting -> HostKeyChecking -> Authenticating
     -> Ready -> OpeningAgent/OpeningPty -> Streaming
     -> Reconnecting | Closed | Failed
```

每次错误必须分类：DNS、TCP 超时、host-key 首见/变更、密码失败、私钥失败、算法不兼容、streamlocal 被拒、agent 协议不兼容、远端权限不足、用户取消。

### 11.2 主机密钥策略

- 首次连接展示算法与 SHA256 指纹，并在显式接受后写入。
- 指纹改变必须硬阻断，不能被普通“重试”绕过。
- 接受变更是独立高风险动作，写审计并记录旧/新指纹。
- 支持 Ed25519、ECDSA P-256、RSA SHA-2；不默认启用 `ssh-rsa` SHA-1。

### 11.3 终端模式

- Direct：标准 SSH PTY，未安装 agent 时可用。
- Persistent：通过 agent 管理 tmux session/window；打开时先 `capture-pane`，再订阅实时输出。
- 用户保存的是偏好模式；agent 暂时不可用只造成当前连接降级，不改写偏好。
- FFI Stream 事件：`connected`、`snapshot`、`stdout`、`windowChanged`、`exit`、`transportDowngraded`、`error`。
- 所有 resize/input 带 session generation，避免重连后的旧事件写入新会话。

### 11.4 并发和恢复

- 长流（终端、日志 follow、监控 subscribe）与短请求分池。
- 短请求每主机设 1/2/4/8 四档并发；SSH/channel/streamlocal 类故障后临时降为 1。
- 使用退避 + 抖动，认证错误不自动重试。
- App 生命周期进入后台时保存可恢复句柄，但 iOS 上主动关闭/暂停不可能持续的本地流。

## 12. Agent 协议与部署

### 12.1 协议 Envelope

```text
Envelope {
  protocol_version,
  message_type,       // request | response | event | cancel
  request_id,
  deadline_ms,
  idempotency_key?,
  capability?,
  payload
}
```

- 4-byte big-endian 长度前缀；默认最大帧 8 MiB，大文件只走 chunk 流。
- 握手返回 agent semver、协议版本、架构、OS、能力位、tmux 版本和最大帧。
- 未知字段可忽略，未知必需能力必须返回结构化 `UnsupportedCapability`。
- 每个请求有 deadline/cancel；服务端限制命令输出、并发、路径和临时文件总量。
- 黄金协议向量由 client/agent 双方在 CI 互测。

### 12.2 Agent 能力清单

- `Handshake`、`Health`、`SystemInfo`。
- `MetricsSnapshot`、`MetricsHistory`、`MetricsSubscribe`、`TopProcesses`。
- `TmuxEnsureSession`、`ListWindows`、`New/Rename/KillWindow`、`Resize`、`Input`、`CapturePane`、`AttachStream`。
- `RunCommand`、`RunCommandStream`、`CancelRun`。
- `ListDir`、`Search`、`ReadRange`、`WriteChunk`、`CommitWrite`、`Mkdir`、`Rename`、`Remove`、`ArchiveDir`。
- `List/KillProcess`、`List/Open/CloseFirewallPort`、`ChangePassword`。
- `DockerProbe/Ps/Images/Run/Ctl/RemoveImage/Logs/PullStream`。
- `ServiceList/Ctl/Logs/LogsFollow`。

### 12.3 事务化部署步骤

1. SSH 登录并探测 `uname -m`、HOME、shell、systemd、现有 agent、磁盘空间。
2. 获取跨客户端远端部署锁，锁包含 owner、nonce、created_at、client_version。
3. 活跃锁返回 `DeployBusy`；超过 TTL 的锁只返回 `RepairRequired`，绝不自动接管。
4. 上传到唯一 `.new.<nonce>`，agent/tmux 分别检查字节数、SHA256、ELF 架构和内置版本。
5. 检查既有 unit 的 `FragmentPath`、原始/有效 `ExecStart`、drop-in 和运行进程真实路径。
6. 发现同名陌生 unit 或路径不归本产品时硬停止。
7. 记录旧文件、启动方式和 enable 状态；创建唯一备份。
8. 只停止确认归属的旧 agent，不结束 tmux；原子替换文件。
9. 按原 system/user/nohup 方式启动，执行 readiness 和严格握手。
10. 任一步失败，进入两阶段回滚；只有旧 agent 重新返回有效协议响应，才算回滚成功。
11. 成功后清理备份和锁；清理失败返回 warning，不伪报完全成功。

## 13. 文件、监控、系统与应用中心

### 13.1 文件传输

- 上传：本地分块 -> 远端 `.part` -> 每块 offset 确认 -> 完整 SHA256 -> fsync -> 原子 rename。
- 下载：远端 identity（路径、大小、mtime、可选 inode）-> 本地安全 `.part` -> offset 续传 -> SHA256 -> commit。
- 远端 identity 改变时拒绝续传，避免拼接两个版本。
- 二进制/超大文件只读保护；在线编辑设最大默认 2 MiB，可配置上限。
- 删除、递归删除、覆盖、符号链接目标变化均要独立确认。

### 13.2 监控

- agent 采样 CPU、load、内存、swap、磁盘、网络、磁盘 IO、Top CPU/内存进程。
- 默认 6 秒采样，可配置 1-3600 秒；跨主机采集默认 4，可配置 1-10。
- redb 采用原始 + 降采样分辨率（例如 6s/1m/15m），保留期可配置。
- 客户端整轮写库完成后再发刷新事件，响应带 generation，迟到结果不能覆盖新结果。
- 手机本地只保存有限摘要和最近窗口，完整历史从 agent 按时间范围读取。

### 13.3 风险动作

- `kill -9`、改 SSH 密码、关闭 SSH 端口、删除镜像/容器、覆盖文件、批量命令属于高风险。
- agent 自身和产品拥有的 tmux 进程默认受保护；除非专门进入修复流程。
- 所有命令以 SSH 用户身份运行；需要 sudo 时明确提示并走独立授权，不缓存 sudo 密码到 AI 上下文。
- Docker 应用模板必须固定镜像引用/摘要、端口、卷和环境变量 schema，不允许从分享链接注入任意 compose。

## 14. 日程领域与原生提醒

### 14.1 日程用例

- 创建、更新、取消、删除、完成事件。
- 单次、每日、每周、每月、每年及 RFC 5545 RRULE 高级模式。
- 多个提醒偏移，例如提前 1 天、1 小时、10 分钟。
- 全天事件、跨日事件、时区事件、固定 instant 事件。
- snooze 10 分钟、1 小时、明天同一时间或自定义。
- 冲突检查只返回 busy interval，不向 Share API 暴露标题和备注。

### 14.2 Notification Coordinator

数据库是唯一事实源，平台 pending notification 只是派生缓存。每次以下事件触发 reconcile：

- 事件/提醒创建、更新、取消、完成。
- App 启动、恢复前台、升级和数据库迁移后。
- 时区、系统时间、locale 改变。
- Android boot 完成、exact alarm 权限变化、通知权限变化。
- 分享投票被截止并导入最终日程。

对账算法：

1. 计算 horizon 内有效 occurrence 和 reminder fire time。
2. 排除已完成、取消、过期、被 exception 删除的 occurrence。
3. 与 `notification_jobs` 及平台 pending 列表做三方差异。
4. 取消孤儿、重建版本落后任务、创建缺失任务。
5. iOS 只提交最近 50 个，留出系统/即时 snooze 余量；每次启动继续滚动。
6. Android 有 exact 权限时用 exact-allow-while-idle；无权限时降级为 inexact 并记录状态。
7. 所有平台 ID 从稳定 UUID 映射，更新必须先取消旧任务再提交新任务。

### 14.3 通知 action

- `OPEN`：打开对应 occurrence（UI 以后实现）。
- `DONE`：标记 occurrence 完成并取消同 occurrence 后续提醒。
- `SNOOZE_10M` / `SNOOZE_1H`：创建一次性 snooze job。
- `SKIP`：只跳过本次 occurrence，不破坏 recurrence rule。

后台 action handler 只能调用受限用例，不加载 SSH 保险库或 AI provider。

### 14.4 权限策略

- 不在首次启动立即索取通知权限。
- 用户创建首个启用提醒时，先解释用途，再请求通知权限。
- 只有用户打开“精确提醒”时请求 Android `SCHEDULE_EXACT_ALARM` 特殊权限；不默认使用受商店严格审核的 `USE_EXACT_ALARM`。
- 权限拒绝不阻止保存日程，但事件必须显示/返回 `reminderCapability=denied|approximate`。

## 15. AI 助手

### 15.1 Provider 抽象

- 首发支持 OpenAI-compatible 与 Anthropic-compatible 两类接口，采用 BYOK，密钥只在本地保险库。
- `AiProvider` 统一输出文本增量、tool call、usage、finish reason 和 provider error。
- provider 配置包括 base URL、model、context window、timeout、是否支持图片/并行工具。
- 不假设模型真实上下文大小；由用户配置并在运行前做上限校验。

### 15.2 自然语言配置日程流程

```text
用户描述
 -> 本地日期/时间实体预解析
 -> AI 生成 ScheduleProposal（只读）
 -> schema + 时区 + recurrence + 权限校验
 -> 冲突检查
 -> 返回新增/修改/删除 diff 和歧义问题
 -> 用户确认
 -> 单个数据库事务提交
 -> Notification Coordinator 对账
 -> 写 schedule_audit 与 ai_audit
```

任何以下情况都必须返回 `NeedsClarification`，不能猜后直接创建：

- “周五”可能指本周已过去还是下周。
- 缺少年份且跨年有两种合理解释。
- 缺少时区且用户正在旅行。
- DST 时间不存在或重复。
- “下午”“晚上”没有用户偏好且影响提醒。
- 修改目标匹配到多个事件。

### 15.3 工具清单

日程工具：

- `schedule.list`、`schedule.get`、`schedule.find_conflicts`
- `schedule.propose_create/update/cancel`
- `schedule.commit_proposal`
- `schedule.snooze`、`schedule.skip_occurrence`
- `poll.propose`、`poll.create`、`poll.add_slots`、`poll.close_and_import`

运维只读工具：

- `host.list/get`、`metrics.snapshot/history`、`process.top`
- `file.list/read/search`、`system.info`、`firewall.list`
- `docker.ps/images/logs`、`service.list/logs`

运维写入工具：

- `file.write/create/mkdir/rename/remove`
- `terminal.run`、`process.kill`、`firewall.open/close`
- `docker.run/control/remove_image`、`service.control`
- `agent.deploy/repair`、`ssh.change_password`

### 15.4 五档权限（独立设计）

1. **观察**：只读日程与主机信息。
2. **日程助理**：可提出日程/投票变更，每次提交确认；无 SSH 写权限。
3. **维护**：允许文件写入和预定义安全服务动作，每个动作确认。
4. **运维**：允许命令和系统写操作；破坏性动作永远确认。
5. **部署**：允许 agent/应用部署和批量操作，只能以有时限、指定主机的会话授权开启。

权限模式与执行策略分开：

- `confirm_every_action`
- `confirm_risky_only`
- `auto_within_session_grant`

即使最高权限，删除、改密、关 SSH 端口、覆盖远端文件、终止关键进程仍不能取消确认。

### 15.5 AI 安全

- 工具 schema 是安全边界，模型不能构造未定义参数。
- 所有路径做 canonicalize/权限校验，所有命令参数做结构化传递；确需 shell 时明确标记。
- 远端文件、日志、命令输出一律当作不可信内容，不能改变系统提示或权限。
- 自动脱敏 token、密码、私钥、Authorization header、连接串。
- 附件默认拒绝敏感文件名，并对内容做私钥/token 特征扫描。
- 每个 tool attempt 在执行前写审计，完成后更新结果；崩溃后能区分“未开始/可能执行/已完成”。
- AI run 和 event 持久化；App 被杀后将 stale run 标为 interrupted，可恢复上下文但不自动重放写工具。
- 工具循环默认 30，可配置安全范围；短 agent 请求使用 1/2/4/8 并发档并自动降级。

## 16. 好友选择出游时间

### 16.1 产品流程

1. 发起人输入活动名称、候选时段、时区、截止时间和可选地点。
2. App 调用 Share API 创建 poll，获得公开 invite URL 与独立 manage token。
3. invite URL 通过 HTTPS 分享；已安装 App 走 Universal/App Link，未安装走网页。
4. 参与者无需注册，输入显示名并对每个时段选择 `yes/maybe/no`。
5. 首次投票返回 participant edit token，仅保存在参与者设备；可在截止前修改。
6. 发起人查看聚合、手动或按规则选中最终时段并关闭。
7. App 将最终 slot 转成本地 event，再由原生提醒系统接管。

### 16.2 后端表

- `polls(id, title, description, organizer_token_hash, invite_token_hash, timezone_id, status, closes_at, expires_at, revision)`
- `poll_slots(id, poll_id, starts_at_utc, ends_at_utc, sort_order)`
- `participants(id, poll_id, display_name, edit_token_hash, created_at, updated_at)`
- `votes(participant_id, slot_id, choice, updated_at)`
- `poll_results(poll_id, selected_slot_id, closed_at)`
- `poll_audit(id, poll_id, action, actor_kind, occurred_at, metadata_json)`

### 16.3 API 草案

- `POST /v1/polls`
- `GET /v1/polls/{inviteToken}`
- `PUT /v1/polls/{inviteToken}/participants/me/votes`
- `GET /v1/polls/{inviteToken}/summary`
- `PATCH /v1/polls/{pollId}`（manage token）
- `POST /v1/polls/{pollId}/close`（manage token）
- `DELETE /v1/polls/{pollId}`（manage token）

所有修改携带 `If-Match: revision` 或请求 revision，冲突返回 409；所有创建/关闭接口支持幂等键。

### 16.4 链接和隐私

- invite token 与 manage token 都至少 128-bit 随机，数据库只存 hash。
- manage token 永不放入公开分享链接。
- Web 设置 `Referrer-Policy: no-referrer`，访问日志不记录完整 token。
- 默认到期后 30 天硬删除投票；发起人可立即删除。
- 不上传参与者通讯录、个人日程标题或备注；“查看空闲”只上传显式同意的 busy interval。
- 限速按 poll、IP 和 token 组合；异常流量触发 CAPTCHA/临时冻结。

## 17. Android/iOS 原生桥接清单

### 17.1 Android

- `POST_NOTIFICATIONS`
- `RECEIVE_BOOT_COMPLETED`
- `SCHEDULE_EXACT_ALARM`（仅启用精确提醒时）
- notification receiver、boot receiver、action receiver
- exact alarm 权限状态广播后重建任务
- 可选 SSH 转发 foreground service：`specialUse` 类型和清晰用途说明，只有用户在前台主动启动
- App Links intent filter + `assetlinks.json`
- Keystore wrapping key、自定义 VMK wrap/unwrap API

### 17.2 iOS

- UserNotifications 权限、category、action handler
- `UNCalendarNotificationTrigger` / 绝对时间 trigger 的统一封装
- pending requests 读取与滚动窗口对账
- Keychain ThisDeviceOnly 与可选 LocalAuthentication access control
- Associated Domains entitlement + `apple-app-site-association`
- App 生命周期进入 background 时暂停无法持续的 SSH 本地流

## 18. 错误模型与可观测性

### 18.1 公共错误类型

- `ValidationError`
- `PermissionDenied`
- `NeedsUserConfirmation`
- `NeedsClarification`
- `AuthenticationFailed`
- `HostKeyUnknown` / `HostKeyChanged`
- `TransportUnavailable` / `AgentChannelBlocked`
- `ProtocolMismatch` / `CapabilityUnavailable`
- `Conflict` / `StaleRevision`
- `Timeout` / `Cancelled`
- `IntegrityMismatch`
- `DeployBusy` / `DeployRepairRequired` / `RollbackIncomplete`
- `NotificationCapabilityDenied` / `ExactAlarmUnavailable`
- `RateLimited` / `RemoteUnavailable`

每个错误包含稳定 code、用户可理解 message key、debug context、retryability 和 sensitive 标记。

### 18.2 日志规则

- 结构化日志带 `request_id/run_id/host_id_hash`，不记录真实地址、用户名和 secret。
- stdout/stderr 默认只保存截断预览，完整结果必须显式保存为本地 artifact。
- release 默认关闭网络 analytics；Crash report 上传前本地脱敏并需用户同意。
- agent journal 不打印请求 payload 中的文件内容、密码或 token。

## 19. 实施阶段与验收门

### Phase 0：基线与技术验证（2 周）

- 建 monorepo、ADR、格式化/lint/test/secret scan。
- Flutter 3.44、Android/iOS 空壳、Rust FFI 双端 hello/stream/取消。
- SSH 库 spike：密码、Ed25519、PTY resize、host-key、streamlocal、local forward、iOS 真机。
- 通知 spike：Android API 24/36、iOS 真机定时、action、权限拒绝、重启。

退出标准：所有关键未知项有实测结论；SSH 库和 FFI 方案冻结。

### Phase 1：领域与数据核心（2-3 周）

- 纯 Dart entities、use cases、错误模型、Repository 接口。
- Drift schema、迁移、事务、数据根和配置。
- 无 UI 的 test harness 与 fake repositories。

退出标准：核心模型 90%+ 单元覆盖；从 schema 1 到当前的迁移测试通过。

### Phase 2：保险库与主机（3-4 周）

- VMK、Keychain/Keystore、vault.db、secret CRUD。
- 主机/分组/标签、TOFU、密码和私钥认证、认证回退。
- 安全日志与 secret redaction。

退出标准：真机重启/锁屏/升级后可用；备份和日志中无明文凭据。

### Phase 3：SSH、终端与端口转发（4-5 周）

- 普通 PTY、输入/resize/取消/重连。
- local forward 生命周期和 Android 可选前台服务。
- Stream backpressure、并发 guard、错误分类。

退出标准：连续 8 小时终端稳定；网络切换、杀 App 和端口冲突可恢复/可解释。

### Phase 4：Linux Agent 与部署（5-6 周）

- 协议、Unix socket、握手、tmux、部署事务和双架构构建。
- direct-streamlocal + stdio bridge。
- 故障注入和两阶段回滚。

退出标准：Ubuntu 24、Debian 12、Rocky/CentOS 兼容环境和 ARM64 真机矩阵通过；失败零残留且旧 tmux 存活。

### Phase 5：运维完整功能（6-8 周，可并行）

- 文件、监控、命令片段、批量执行。
- 系统管理、Docker、镜像、容器、systemd 和日志流。
- 一次性授权与审计。

退出标准：每个结构化请求有 contract test；文件传输故障矩阵与高风险确认测试通过。

### Phase 6：日程与原生提醒（4-5 周）

- recurrence/occurrence/timezone/DST。
- Notification Coordinator、权限、boot、action、滚动窗口。
- 冲突、snooze、完成和 skip。

退出标准：跨 30 个 IANA 时区的属性测试通过；Android 重启/权限撤销和 iOS 64 限制实测通过。

### Phase 7：AI 助手（4-6 周）

- provider、会话、工具 loop、五档权限、确认、审计、暂停/继续/终止。
- 日程自然语言 proposal/diff/commit。
- 运维工具和提示注入隔离。

退出标准：fake model 确定性 E2E 全过；模型无法通过任何提示绕过权限或读取 secret。

### Phase 8：分享预约（3-4 周）

- Share API、PostgreSQL migration、token、投票、并发版本、截止。
- Universal/App Links、App 端 Repository；Web UI 仅留契约和后续入口。

退出标准：未安装 App 的 URL 能落到正确 Web 路由；token 枚举、重复提交、并发关闭和过期删除测试通过。

### Phase 9：发布级加固（4-6 周）

- 性能、故障注入、真实设备、SBOM、签名、隐私清单、恢复演练。
- 非 UI 功能冻结、API 文档、数据库和协议兼容策略。

退出标准：本文件第 23 节 Definition of Done 全部满足。

## 20. 测试计划

### 20.1 单元与属性测试

- recurrence 在月末、闰年、DST、跨年和时区切换下的性质测试。
- 权限矩阵：每个 tool × permission mode × exec policy。
- 部署脚本 shell quote、路径、锁 TTL 和状态转换。
- 文件 chunk/offset/hash/identity 和中断恢复。
- token 生成、hash、revision 和幂等。
- 所有数据库 migration 的 upgrade、空库和脏数据测试。

### 20.2 协议与模糊测试

- client/agent 黄金帧、旧版本兼容和未知字段。
- frame length、CBOR、路径、Docker 参数、tmux window id fuzz。
- 断帧、超大帧、乱序 event、重复 request id、取消竞态。

### 20.3 SSH 实验室

- Ubuntu 24、Debian 12、Rocky 9、CentOS 7.9 兼容样本。
- OpenSSH 新/旧配置、禁用 streamlocal、密码禁用、密钥算法差异。
- x86_64 和 ARM64；高延迟、丢包、断网、IP 切换。
- agent 当前版/旧版/损坏版/陌生同名 systemd unit。

### 20.4 设备矩阵

- Android API 24、31、33、34、36；至少 Pixel、Samsung、小米/OPPO 一台真机。
- iOS 最低版本、当前主版本、最新版本；至少两代 iPhone 真机。
- 通知权限拒绝/允许/撤销、exact alarm 撤销、重启、改时区、手工改时间、省电模式。
- App 前台/后台/强停/升级/卸载重装。

### 20.5 安全测试

- OWASP MASVS 对照、自有 threat model、依赖审计、secret scan、SBOM。
- MITM/host-key change、恶意 agent、恶意分享 URL、提示注入、路径穿越、symlink race。
- 数据库/备份/日志/Crash dump/剪贴板敏感信息检查。
- Share API token 枚举、IDOR、速率限制、CSRF/CORS、重放和过期。

## 21. CI/CD 与供应链

- PR：Dart format/analyze/test、Rust fmt/clippy/test、schema generation diff、OpenAPI lint。
- Android：debug/release 构建、Manifest 权限门禁、APK/AAB ABI/签名检查。
- iOS：模拟器和 device archive 编译、entitlement/Privacy Manifest 检查。
- agent：musl 双架构、版本/协议一致性、payload 解压逐字节 SHA256 门禁。
- Share API：migration test、container scan、OpenAPI contract test。
- 每个 release 生成 SBOM、SHA256、签名和可追溯 build metadata。
- 发布资产不覆盖旧 tag；App、agent、协议和 schema 版本分别管理。
- 自动更新只做版本检查和跳转商店/官方发布页；首发不做静默自更新。

## 22. 工作量与团队建议

粗估为 45-60 工程人周，不含正式 UI、商店审核等待和品牌设计。

建议最小团队：

- 1 名 Flutter/Dart 工程师：领域、数据库、日程、通知、AI 编排。
- 1 名 Rust/系统工程师：SSH、agent、tmux、文件、部署、安全。
- 1 名后端工程师：Share API、PostgreSQL、链接、部署与安全。
- QA/安全可兼职但发布前必须有独立复核。

三名核心工程师并行，非 UI 功能达到 release candidate 预计 5-7 个月；单人完成更合理的预期是 12-15 个月。任何明显短于该范围的承诺都会挤压真实设备、故障注入和安全工作。

## 23. Definition of Done

只有同时满足以下条件，才算“除前端 UI 外完成”：

- Android/iOS release 构建成功，最小壳能初始化全部服务。
- 所有公开 Use Case 都可通过测试 harness 调用，不依赖页面。
- C-SSH 功能覆盖矩阵中计划内项目都有自动化或真机验收证据。
- 远端 agent 双架构可部署、升级、修复、回滚，旧 tmux 不丢。
- 凭据没有出现在 app.db、日志、Crash report、Share API 或 AI 上下文。
- 日程在时区/DST/重复/重启/权限撤销场景下对账正确。
- AI 所有写操作可追溯、可确认、不可越权，崩溃后状态明确。
- 分享链接支持未安装 App 的 fallback，token、并发、过期和删除正确。
- 数据库 migration、协议兼容、OpenAPI 和 AI tool schema 已版本化。
- 全量 lint/test/security scan/SBOM/真实设备矩阵通过。
- 已完成品牌、许可证、隐私政策和商店权限用途审查。

## 24. 关键风险与处理

| 风险 | 影响 | 处理 |
| --- | --- | --- |
| C-SSH 无源码/许可证 | 无法合法复用实现 | 完全独立实现、重命名、保留设计证据与 clean-room 边界 |
| iOS 后台挂起 | SSH 转发/长流中断 | 明确前台限制，远端 tmux/agent 保持任务，传输可续 |
| Android exact alarm 审核/权限 | 提醒可能不精确 | `SCHEDULE_EXACT_ALARM` 按需申请，拒绝时降级并显示能力状态 |
| iOS 64 pending limit | 远期提醒丢失 | 最近 50 个滚动窗口 + 每次启动/变化对账 |
| SSH 库跨平台差异 | iOS 编译或老服务端不兼容 | Phase 0 真机 spike 后冻结；保留 stdio bridge |
| agent 部署破坏现网 | 高风险 | 锁、归属检查、hash、readiness、双阶段回滚、故障注入 |
| AI 提示注入/误操作 | 服务器或日程被错误修改 | 工具权限、确认、schema、审计、remote text 不可信 |
| 大文件/弱网 | 传输失败或误报成功 | chunk + offset + identity + SHA256 + 原子 commit |
| 分享链接泄漏 | 活动信息暴露 | 高熵 token、最小数据、no-referrer、过期、删除、限速 |
| 双语言数据库并发 | 数据损坏 | app.db 与 vault.db 单一写入者，统一 data root |

## 25. 当前默认决策与以后需要产品确认的项

为不阻塞开发，本计划默认：

- 个人日程只在设备本地；Share Poll 数据上云。
- AI 使用用户自己的 provider key，不经自家 AI 代理。
- Android 精确提醒按需申请 `SCHEDULE_EXACT_ALARM`。
- iOS 端口转发只保证前台；Android 前台服务是可选功能。
- 分享投票可匿名参与，默认 30 天后删除。
- 正式 UI 在所有核心接口和状态机稳定后单独规划。

开始正式开发前还需确定：产品名称/包名、分享域名、后端部署区域、隐私保留期、是否需要账号与个人日程同步、首发支持的 AI provider 清单、是否把 Docker 应用商城纳入首个商店版本。

## 26. 参考资料

- C-SSH 公开仓库与功能说明：<https://github.com/suiyuebaobao/C-SSH>
- C-SSH v0.6.10 Release：<https://github.com/suiyuebaobao/C-SSH/releases/tag/v0.6.10>
- Flutter 官方应用架构：<https://docs.flutter.dev/app-architecture/guide>
- Flutter 官方 offline-first 指南：<https://docs.flutter.dev/app-architecture/design-patterns/offline-first>
- Android 官方 AlarmManager/精确提醒：<https://developer.android.com/develop/background-work/services/alarms>
- Android 13+ 通知权限：<https://developer.android.com/develop/ui/compose/notifications/notification-permission>
- Android App Links：<https://developer.android.com/training/app-links/about>
- Android Foreground Service 类型：<https://developer.android.com/develop/background-work/services/fgs/service-types>
- Apple 本地通知：<https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app>
- Apple 后台执行模式：<https://developer.apple.com/documentation/Xcode/configuring-background-execution-modes>
- Apple Universal Links/Associated Domains：<https://developer.apple.com/documentation/Xcode/supporting-associated-domains>
- Apple Keychain Services：<https://developer.apple.com/documentation/security/keychain-services/>
- Android Keystore：<https://developer.android.com/privacy-and-security/keystore>
- Flutter Local Notifications：<https://pub.dev/packages/flutter_local_notifications>
- Drift：<https://pub.dev/packages/drift>
- flutter_rust_bridge：<https://pub.dev/packages/flutter_rust_bridge>
