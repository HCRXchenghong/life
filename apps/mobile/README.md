# Daylink Mobile Core

Flutter Android/iOS 工程。目前按需求不实现产品页面，只提供启动壳和可被后续 UI 调用的完整非 UI 服务。

已接入：

- Drift `app.db`：主机、分组、标签、known-host、Agent 状态、端口转发、命令片段/批次、可续传任务、日程、提醒、AI 与分享引用。
- `flutter_secure_storage`：设备绑定的 SSH/AI secret reference 存储；明文不进入 Drift。
- Android/iOS 原生本地通知：重复规则、时区/DST、通知窗口、完成与 snooze、启动/恢复对账。
- 第三方 Responses/Images API Provider、Daylink Web Gateway 与 Codex App Server JSON-RPC 客户端。
- 好友选时间：创建/刷新/定稿、管理令牌安全存储、版本冲突保护、定稿后导入日程与提醒。
- AI 工具：递归 strict schema 校验、风险审批、日程/投票工具，以及系统、监控、进程、文件、tmux、systemd、Docker 和命令工具。
- Codex：Agent 启动官方 `codex app-server`，Flutter transport 负责 JSON-RPC 消息泵、审批请求和关闭回收；Provider 读取远端用户级 Codex 原生配置，不复用 Daylink Web 保存的第三方 API Key。
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
