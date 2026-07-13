"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";

type ApiResult = {
  next?: string;
  error?: { message?: string };
};

export function AdminSetupForm() {
  const [busy, setBusy] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [message, setMessage] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    const form = event.currentTarget;
    const payload = Object.fromEntries(new FormData(form));
    try {
      const response = await fetch("/api/auth/setup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });
      const result = (await response.json()) as ApiResult;
      if (!response.ok) {
        setMessage(result.error?.message ?? "创建失败，请稍后重试");
        return;
      }
      window.location.assign(result.next ?? "/admin/setup/2fa");
    } catch {
      setMessage("网络连接失败，请稍后重试");
    } finally {
      setBusy(false);
    }
  }

  return (
    <AdminAuthFrame privacyText="用户数据采用端到端加密，管理员无法读取">
      <section className="admin-auth-content" aria-labelledby="setup-title">
        <h1 id="setup-title">创建管理员账号</h1>
        <p className="admin-auth-subtitle">用于登录 Daylink 管理后台</p>

        <form className="admin-auth-form" onSubmit={submit} noValidate>
          <label>
            <span>管理员账号</span>
            <input
              name="username"
              autoComplete="username"
              inputMode="text"
              minLength={4}
              maxLength={32}
              pattern="[A-Za-z0-9][A-Za-z0-9._-]{3,31}"
              placeholder="请输入账号"
              required
            />
          </label>

          <PasswordField
            label="登录密码"
            name="password"
            placeholder="至少 12 位"
            visible={showPassword}
            onToggle={() => setShowPassword((value) => !value)}
          />

          <PasswordField
            label="确认密码"
            name="confirmPassword"
            placeholder="请再次输入密码"
            visible={showConfirmation}
            onToggle={() => setShowConfirmation((value) => !value)}
          />

          <button className="admin-auth-primary" type="submit" disabled={busy}>
            {busy ? "创建中…" : "下一步"}
          </button>
          <p className="admin-auth-message" role="status">
            {message || "下一步将绑定 Microsoft Authenticator"}
          </p>
        </form>
      </section>
    </AdminAuthFrame>
  );
}

export function AdminLoginForm() {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))),
      });
      const result = (await response.json()) as ApiResult;
      if (!response.ok) {
        setMessage(result.error?.message ?? "登录失败");
        return;
      }
      window.location.assign(result.next ?? "/admin");
    } catch {
      setMessage("网络连接失败，请稍后重试");
    } finally {
      setBusy(false);
    }
  }

  return (
    <AdminAuthFrame privacyText="后台会话将在 12 小时后自动失效">
      <section className="admin-auth-content" aria-labelledby="login-title">
        <h1 id="login-title">登录管理后台</h1>
        <p className="admin-auth-subtitle">请输入管理员账号与动态验证码</p>
        <form className="admin-auth-form" onSubmit={submit}>
          <label><span>管理员账号</span><input name="username" autoComplete="username" required placeholder="请输入账号" /></label>
          <PasswordField label="登录密码" name="password" placeholder="请输入密码" visible={showPassword} onToggle={() => setShowPassword((value) => !value)} />
          <label><span>动态验证码</span><input name="code" autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} required placeholder="6 位验证码" /></label>
          <button className="admin-auth-primary" disabled={busy}>{busy ? "验证中…" : "登录"}</button>
          <p className="admin-auth-message" role="alert">{message || "使用 Microsoft Authenticator 中的动态验证码"}</p>
        </form>
      </section>
    </AdminAuthFrame>
  );
}

export function PendingSetupNotice({
  authorized,
  reason,
}: {
  authorized: boolean;
  reason?: "allowlist_missing" | "forbidden";
}) {
  const description = reason === "allowlist_missing"
    ? "请先在部署环境配置管理员初始化白名单"
    : reason === "forbidden"
      ? "当前托管身份不在管理员初始化白名单中"
      : authorized
        ? "账号已创建，正在继续绑定双重验证"
        : "已有设备正在创建管理员账号，请稍后重试";
  return (
    <AdminAuthFrame privacyText="初始化会话将在 10 分钟后自动失效">
      <section className="admin-auth-content" aria-labelledby="pending-title">
        <h1 id="pending-title">{reason ? "无法初始化后台" : "管理员初始化中"}</h1>
        <p className="admin-auth-subtitle">{description}</p>
      </section>
    </AdminAuthFrame>
  );
}

function AdminAuthFrame({ children, privacyText }: { children: React.ReactNode; privacyText: string }) {
  return (
    <main className="admin-auth-shell">
      <Link className="admin-auth-brand" href="/" aria-label="Daylink 首页">
        <span className="admin-auth-brand-mark" aria-hidden="true" />
        <span>Daylink</span>
      </Link>
      {children}
      <p className="admin-auth-privacy">{privacyText}</p>
    </main>
  );
}

function PasswordField({
  label,
  name,
  placeholder,
  visible,
  onToggle,
  disabled = false,
}: {
  label: string;
  name: string;
  placeholder: string;
  visible: boolean;
  onToggle: () => void;
  disabled?: boolean;
}) {
  return (
    <label>
      <span>{label}</span>
      <span className="admin-auth-password">
        <input
          name={name}
          type={visible ? "text" : "password"}
          autoComplete="new-password"
          minLength={12}
          maxLength={128}
          placeholder={placeholder}
          required
          disabled={disabled}
        />
        <button type="button" onClick={onToggle} aria-label={visible ? "隐藏密码" : "显示密码"} tabIndex={disabled ? -1 : 0}>
          {visible ? "隐藏" : "显示"}
        </button>
      </span>
    </label>
  );
}
