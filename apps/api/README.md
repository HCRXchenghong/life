# Daylink Go API

Go + MySQL 后端，提供：

- 应用自有管理员首次初始化、密码 + Microsoft Authenticator TOTP、会话撤销、改密和 TOTP 重绑；
- App 账号创建/启停/重置、密码登录、短访问令牌、一次性刷新令牌轮换；
- 第三方 Responses/Images API 配置、加密 Key、连通测试、文本和生图网关；
- Plus/Pro/Max 套餐、月度账号额度、周卡/月卡/季度卡/年卡到期，以及失败释放的原子用量预占；
- 面向用户 SSH 主机 Codex 的 OpenAI-compatible `/v1` 网关与短期哈希凭证，上游 API Key 不离开 Go 服务；
- 公开好友选时间、编辑凭据、管理凭据和乐观锁定稿；
- 按 App 账号隔离的密文对象、幂等写入、增量游标和 SSE 变更通知；
- 最小化安全审计，禁止记录 Secret、提示词、内容或完整远程输出。

## 运行

复制 `.env.example`，填写所有必填变量后：

```text
set -a; source .env; set +a
go run ./cmd/daylink-api
```

默认自动运行内嵌迁移。生产可由发布任务先运行迁移，再把 `AUTO_MIGRATE` 设为 `false`。API 不直接暴露到公网；通过同源反向代理提供 App/后台 `/api/*` 和短期凭证保护的 Codex `/v1/*`。

```text
gofmt -w .
go test ./...
go vet ./...
```
