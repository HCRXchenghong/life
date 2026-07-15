import QRCode from "qrcode";
import { FormEvent, ReactNode, useEffect, useState } from "react";
import { api } from "./api";
import { Brand } from "./App";

type Result = { next?: string };

export function AdminSetup({ onCreated }: { onCreated: () => void }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      await api<Result>("/api/auth/setup", {
        method: "POST",
        body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))),
      });
      onCreated();
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "创建失败");
    } finally {
      setBusy(false);
    }
  }
  return (
    <AuthFrame privacy="用户内容由客户端端到端加密，管理员无法读取">
      <h1>创建管理员账号</h1>
      <p className="admin-auth-subtitle">用于登录 Daylink 管理后台</p>
      <form className="admin-auth-form" onSubmit={submit}>
        <Field label="管理员账号"><input name="username" autoComplete="username" minLength={4} maxLength={32} pattern="[A-Za-z0-9][A-Za-z0-9._-]{3,31}" required autoFocus /></Field>
        <Field label="登录密码"><input name="password" type="password" autoComplete="new-password" minLength={12} maxLength={128} required /></Field>
        <Field label="确认密码"><input name="confirmPassword" type="password" autoComplete="new-password" minLength={12} maxLength={128} required /></Field>
        <Field label="部署初始化口令"><input name="setupToken" type="password" autoComplete="off" maxLength={256} placeholder="生产部署时必填" /></Field>
        <button className="admin-auth-primary" disabled={busy}>{busy ? "创建中…" : "下一步"}</button>
        <p className="admin-auth-message" role="alert">{message || "下一步将绑定 Microsoft Authenticator"}</p>
      </form>
    </AuthFrame>
  );
}

export function AdminLogin({ onLogin }: { onLogin: () => void }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      await api<Result>("/api/auth/login", { method: "POST", body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))) });
      onLogin();
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "登录失败");
    } finally {
      setBusy(false);
    }
  }
  return (
    <AuthFrame privacy="后台会话将在 12 小时后自动失效">
      <h1>登录管理后台</h1>
      <p className="admin-auth-subtitle">管理员账号、密码和动态验证码</p>
      <form className="admin-auth-form" onSubmit={submit}>
        <Field label="管理员账号"><input name="username" autoComplete="username" required autoFocus /></Field>
        <Field label="登录密码"><input name="password" type="password" autoComplete="current-password" required /></Field>
        <Field label="动态验证码"><input name="code" autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} required /></Field>
        <button className="admin-auth-primary" disabled={busy}>{busy ? "验证中…" : "登录"}</button>
        <p className="admin-auth-message" role="alert">{message || "使用 Microsoft Authenticator 中的 6 位验证码"}</p>
      </form>
    </AuthFrame>
  );
}

type Enrollment = { username: string; secret: string; uri: string; expiresAt: string };

export function AdminEnrollment({ onComplete, onRestart }: { onComplete: () => void; onRestart: () => void }) {
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null);
  const [qr, setQR] = useState("");
  const [code, setCode] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    let active = true;
    api<Enrollment>("/api/auth/setup/enrollment")
      .then(async (value) => {
        const image = await QRCode.toDataURL(value.uri, { width: 368, margin: 0, errorCorrectionLevel: "M" });
        if (active) { setEnrollment(value); setQR(image); }
      })
      .catch((reason: unknown) => active && setMessage(reason instanceof Error ? reason.message : "无法加载绑定信息"));
    return () => { active = false; };
  }, []);
  async function verify(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    try {
      await api<Result>("/api/auth/setup/verify", { method: "POST", body: JSON.stringify({ code }) });
      onComplete();
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "验证失败");
    } finally { setBusy(false); }
  }
  async function restart() {
    setBusy(true);
    try {
      await api("/api/auth/setup", { method: "DELETE" });
      onRestart();
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "暂时无法返回");
      setBusy(false);
    }
  }
  return (
    <AuthFrame privacy="验证成功前，管理员账号不会启用">
      <h1>绑定双重验证</h1>
      <p className="admin-auth-subtitle">使用 Microsoft Authenticator 扫描二维码</p>
      <div className="admin-auth-qr">{qr ? <img src={qr} width="184" height="184" alt="Microsoft Authenticator 绑定二维码" /> : <span>正在生成二维码…</span>}</div>
      {enrollment && <div className="admin-auth-secret"><code>{enrollment.secret.match(/.{1,4}/g)?.join(" ")}</code></div>}
      <form className="admin-auth-form admin-auth-totp-form" onSubmit={verify}>
        <Field label="动态验证码"><input value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))} inputMode="numeric" pattern="[0-9]{6}" maxLength={6} required autoFocus /></Field>
        <button className="admin-auth-primary" disabled={busy || !enrollment}>{busy ? "验证中…" : "验证并进入后台"}</button>
        <button className="admin-auth-back" type="button" onClick={() => void restart()} disabled={busy}>返回上一步</button>
        <p className="admin-auth-message" role="alert">{message}</p>
      </form>
    </AuthFrame>
  );
}

export function PendingSetup() {
  return <AuthFrame privacy="初始化会话将在 10 分钟后失效"><h1>管理员初始化中</h1><p className="admin-auth-subtitle">已有设备正在创建管理员账号，请稍后重试</p></AuthFrame>;
}

function AuthFrame({ children, privacy }: { children: ReactNode; privacy: string }) {
  return <main className="admin-auth-shell"><Brand /><div className="admin-auth-stage"><section className="admin-auth-content">{children}</section><p className="admin-auth-privacy">{privacy}</p></div></main>;
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return <label><span>{label}</span>{children}</label>;
}
