# Daylink React Web

独立部署的 React + Vite 前端，包含 `/admin` 后台和 `/poll/:token` 公开投票页。所有业务 API、鉴权、Secret 和数据库访问都在 `apps/api`；浏览器包不包含 AI Key 或主密钥。

```text
npm ci
npm run dev
npm run lint
npm run typecheck
npm run test
```

开发服务器把 `/api` 代理到 `http://127.0.0.1:8080`。生产镜像由 Caddy 提供静态 SPA，并把 `/api/*` 反向代理到 Go API。

首次访问 `/admin` 时创建唯一管理员账号，再绑定并验证 Microsoft Authenticator。后台不依赖 GPT/ChatGPT 登录。二维码由浏览器直接根据一次性 `otpauth://` 数据生成，不调用二维码服务。

App 账号页可由管理员发放、续期、切换或取消 Plus/Pro/Max 套餐，并显示到期日；设置页配置 Plus/Pro 的自然月 Token 额度，Max 固定为无限用量额度。所有套餐写操作仍受后台会话、同源校验和安全审计保护。
