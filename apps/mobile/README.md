# Daylink Mobile Core

Flutter Android/iOS 工程。底层服务与已审核的产品页面正按真实接口逐页落地。

已接入：

- Drift `app.db`：主机、分组、标签、known-host、Agent 状态、端口转发、命令片段/批次、可续传任务、日程、提醒、AI 与分享引用。
- `flutter_secure_storage`：设备绑定的 SSH/AI secret reference 存储；明文不进入 Drift。
- Android/iOS 原生本地通知：重复规则、时区/DST、通知窗口、完成与 snooze、启动/恢复对账。
- 第三方 Responses/Images API Provider、Daylink Web Gateway 与 Codex App Server JSON-RPC 客户端。
- 好友选时间：创建/刷新/定稿、管理令牌安全存储、版本冲突保护、定稿后导入日程与提醒。
- 密文同步接收层：账号级增量拉取、严格密文/nonce 校验、单调游标、SSE 与前台触发、本地密文缓存；内容密钥未解锁时不伪装成已恢复。
- 端到端密钥初始化：Rust 生成 CMK 与高熵恢复密钥，账号级 `vault.db` 使用设备密钥 AEAD 保护并原子写入；后端只接收恢复密钥信封，并发初始化冲突不会覆盖已有密钥。
- 恢复密钥保存：真实恢复密钥仅在待确认页显示，离开前需二次确认；页面退到后台即遮挡，复制内容在离页、确认或 2 分钟后按值清理，确认成功后 Rust 才从 `vault.db` 删除待确认副本。
- 新设备恢复密钥解锁：App 只下载账号隔离的加密信封，恢复密钥在本机严格解码后交给 Rust 以账号绑定 AAD 解封 CMK；密钥不会发往后端，错误、篡改或跨账号信封不会创建或覆盖本机 `vault.db`。
- 受信设备批准：已登录且持有 CMK 的设备可查看同账号 10 分钟一次性请求，核对由账号、请求 ID 与 X25519 公钥共同派生的六位验证码后批准或拒绝；Rust 使用 X25519 + HKDF-SHA256 + AES-256-GCM 仅向新设备公钥封装 CMK，Go/MySQL 只保存公钥、定长密文和单向状态，无法读取 CMK。
- 新设备等待批准：App 可幂等发起、恢复、轮询和取消请求，前后台切换会暂停/续查；一次性请求证明与 X25519 私钥只保存在设备密钥加密的 `vault.db`，后端仅存证明哈希，因此访问令牌轮换后可续查但同账号其他设备不能冒领；批准包先由 Rust 完整验证并落地 CMK，随后才消费后端信任状态，恢复密钥入口始终可用。
- AI 工具：递归 strict schema 校验、风险审批、日程/投票工具，以及系统、监控、进程、文件、tmux、systemd、Docker 和命令工具。
- 双 AI 模式：本地 AI 使用 App 访问令牌调用 Daylink 网关；SSH Agent 在用户自己的主机启动官方 `codex app-server`，使用后台签发的短期账号凭证和自定义 Responses Provider，不接收上游 API Key。
- Codex：Flutter transport 负责 JSON-RPC 消息泵、审批请求和关闭回收；Agent 为每个会话创建 `0700` 隔离 `CODEX_HOME`，令牌仅注入子进程环境，配置不落令牌，停止后删除会话目录。
- `flutter_rust_bridge` + Cargokit：把 `crates/mobile-core` 的 russh SSH、PTY、Agent 协议、事务安装和 loopback port forward 编入 Android/iOS。
- `DaylinkServices`：统一暴露数据库、保险库、Repository、AI、分享、通知、原生 SSH 与工具注册入口，供后续 UI 直接调用。

常用验证：

```sh
flutter test
dart analyze --format=machine
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

桥接接口变更后：

```sh
flutter_rust_bridge_codegen generate
dart run build_runner build
```

当前 FRB 2.12 的依赖检查不接受 Analyzer 13 所需的 Freezed 预发布版本；仓库已提交完整生成文件。更新桥接前应先升级到修复该判断的 FRB 版本，或在隔离分支完成生成并用真实锁文件执行 `build_runner`、分析、测试和双平台构建，不要提交伪造锁文件。

Flutter 3.44 的 `flutter analyze` 在当前包含中文的绝对路径上可能触发 LSP 消息截断；CI 应同时运行 `dart analyze --format=machine` 与真实双平台构建。

原生构建胶水会把 Cargo、`rustc` 与 `rustdoc` 固定到同一个 Rustup stable 工具链，避免 Homebrew Rust 抢占 PATH；Android Cargo 并发限制为 2，最终 NDK LLD 链接限制为单线程。该配置只影响构建资源峰值，不改变运行时功能或目标架构。
