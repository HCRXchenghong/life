# Daylink 独立部署

该目录部署 MySQL 8.4、Go API 和 Caddy/React，不依赖 Sites、Cloudflare Worker、D1 或 R2。

1. 复制 `.env.example` 为 `.env`。
2. 分别生成两个 32 字节随机值并以 Base64 填入两个 master key。
3. 生成独立的 `ADMIN_SETUP_TOKEN`；它只在第一次创建管理员时输入，不能复用管理员密码。
4. 设置不同的 MySQL 普通用户和 root 密码。
5. 把 `PUBLIC_ORIGIN` 设置为正式 HTTPS Origin，例如 `https://daylink.example.com`。
6. 运行：

```text
docker compose --env-file deploy/.env -f deploy/docker-compose.yml up -d --build
```

正式环境应在 Caddy 前配置 TLS，或把 Caddyfile 的站点地址改为正式域名以使用 Caddy 自动 HTTPS；Compose 已持久化 `/data` 和 `/config`。数据库与 API 只在内部 Docker 网络，不要额外映射端口。

备份至少包含 `mysql-data`、`generated-assets` 和 Caddy 数据卷。恢复演练必须验证数据库迁移版本、管理员 TOTP、App 登录、投票链接和密文同步游标。
