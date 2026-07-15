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

## 局域网 HTTPS

局域网运行使用 Caddy 内部 CA，避免管理员密码、2FA、App 登录和同步数据通过 Wi-Fi 明文传输：

1. 查询宿主机的局域网 IP。在 `.env` 中设置 `PUBLIC_ORIGIN=https://<局域网IP>:8443`、`LAN_SITE_ADDRESS=https://<局域网IP>`、`LAN_TLS_SERVER_NAME=<局域网IP>` 和 `HTTPS_PORT=8443`。`LAN_TLS_SERVER_NAME` 让未发送 IP-SNI 的客户端也能选择正确证书。
2. 运行：

```text
docker compose --env-file deploy/.env -p daylink -f deploy/docker-compose.yml -f deploy/docker-compose.lan.yml up -d --build
```

3. 从 `daylink_caddy-data` 卷导出 `/data/caddy/pki/authorities/local/root.crt`，并仅在需要访问 Daylink 的电脑或手机上安装为受信任根证书。
4. 浏览器和 Flutter App 使用 `https://<局域网IP>:8443`。不要在正式公网部署中使用内部 CA。
