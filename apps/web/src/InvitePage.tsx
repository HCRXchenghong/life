import { FormEvent, useEffect, useState } from "react";
import { Brand } from "./App";
import { api } from "./api";

type InvitationStatus = { valid: boolean; expiresAt: string };

export function InvitePage({ token }: { token: string }) {
  const [status, setStatus] = useState<InvitationStatus | null>(null);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [created, setCreated] = useState("");

  useEffect(() => {
    let active = true;
    api<InvitationStatus>(`/api/invitations/${encodeURIComponent(token)}`)
      .then((result) => { if (active) setStatus(result); })
      .catch((reason: unknown) => { if (active) setMessage(reason instanceof Error ? reason.message : "邀请链接不可用"); });
    return () => { active = false; };
  }, [token]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const result = await api<{ created: boolean; username: string }>(`/api/invitations/${encodeURIComponent(token)}`, {
        method: "POST",
        body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))),
      });
      setCreated(result.username);
      setStatus(null);
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "账号创建失败");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="admin-auth-shell">
      <Brand />
      <div className="admin-auth-stage">
        <section className="admin-auth-content">
          {created ? <>
            <span className="admin-invite-success-mark">✓</span>
            <h1>账号已创建</h1>
            <p className="admin-auth-subtitle">{created} 现在可以在 Daylink App 中登录</p>
          </> : status ? <>
            <h1>接受 Daylink 邀请</h1>
            <p className="admin-auth-subtitle">设置 App 登录账号，邀请有效至 {new Date(status.expiresAt).toLocaleString("zh-CN")}</p>
            <form className="admin-auth-form" onSubmit={submit}>
              <label><span>邀请码</span><input name="code" autoComplete="one-time-code" maxLength={32} required autoFocus /></label>
              <label><span>App 账号</span><input name="username" autoComplete="username" minLength={4} maxLength={32} pattern="[A-Za-z0-9][A-Za-z0-9._-]{3,31}" required /></label>
              <label><span>登录密码</span><input name="password" type="password" autoComplete="new-password" minLength={12} maxLength={128} required /></label>
              <label><span>确认密码</span><input name="confirmPassword" type="password" autoComplete="new-password" minLength={12} maxLength={128} required /></label>
              <button className="admin-auth-primary" disabled={busy}>{busy ? "创建中…" : "创建 App 账号"}</button>
              <p className="admin-auth-message" role="alert">{message}</p>
            </form>
          </> : <>
            <h1>{message ? "邀请链接不可用" : "正在验证邀请"}</h1>
            <p className="admin-auth-subtitle">{message || "请稍候"}</p>
          </>}
        </section>
      </div>
    </main>
  );
}
