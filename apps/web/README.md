# Daylink Web

Daylink 的 Cloudflare Worker / D1 / R2 服务，包含：

- `/admin`：管理员账号、密码与 Microsoft Authenticator TOTP 保护的 AI Provider 配置、连通测试、生图、投票创建与设备令牌签发/撤销。
- TOTP 二维码只在浏览器本地从一次性 `otpauth://` 数据生成，不调用第三方二维码服务。
- `/api/assistant/*`：移动端使用 Daylink Token 调用的 Responses/Images 网关；Provider Key 不返回设备。
- `/api/polls/*` 与 `/poll/:token`：公开时间投票、匿名参与、编辑令牌和乐观锁定稿。
- D1：Provider 密文、AI 运行、审计、投票与生成资产元数据。
- R2：AI 生成图片原始文件。

## 命令

```text
npm ci
npm run dev
npm run lint
npm run typecheck
npm run test
```

运行变量 `AI_SECRET_MASTER_KEY` 与 `AUTH_SECRET_MASTER_KEY` 都是独立生成的
32 字节随机值的 Base64。只通过本地 `.env` 或 Sites Secret 注入，不写入仓库。
首次初始化必须在 Sites 访问策略保护下完成，2FA 激活后再开放后台登录入口。
生产环境还必须设置 `ADMIN_BOOTSTRAP_EMAILS`；只有经过 ChatGPT 托管身份验证且
命中此白名单的部署者才能创建首个管理员，防止公网首访者抢注。
移动端令牌从后台签发，数据库只保存
SHA-256 哈希，明文只在签发响应中返回一次。
数据库迁移位于 `drizzle/`，HTTP 契约位于仓库根目录
`packages/contracts/openapi.yaml`。
