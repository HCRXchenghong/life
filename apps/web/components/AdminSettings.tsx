"use client";
/* eslint-disable @next/next/no-img-element -- the QR code is generated locally from a short-lived TOTP URI */

import QRCode from "qrcode";
import { FormEvent, useEffect, useState } from "react";
import { AdminCssIcon, AdminShell } from "./AdminShell";

type DialogName = "password" | "totp" | null;

type TotpEnrollment = {
  username: string;
  secret: string;
  uri: string;
  expiresAt: string;
};

type ApiResult = {
  reauthenticate?: boolean;
  error?: { message?: string };
};

export function AdminSettings({ username }: { username: string }) {
  const [dialog, setDialog] = useState<DialogName>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [currentCode, setCurrentCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [enrollment, setEnrollment] = useState<TotpEnrollment | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState("");
  const [newCode, setNewCode] = useState("");
  const [showSecret, setShowSecret] = useState(false);

  useEffect(() => {
    if (!dialog) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Escape" || busy) return;
      if (dialog === "totp" && enrollment) void cancelTotp();
      else closeDialog();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  function openDialog(name: Exclude<DialogName, null>) {
    setDialog(name);
    setMessage("");
    setCurrentPassword("");
    setCurrentCode("");
    setNewPassword("");
    setConfirmPassword("");
    setEnrollment(null);
    setQrDataUrl("");
    setNewCode("");
    setShowSecret(false);
  }

  function closeDialog() {
    if (busy) return;
    setDialog(null);
    setMessage("");
  }

  async function changePassword(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!/^\d{6}$/.test(currentCode)) {
      setMessage("请输入当前验证器显示的 6 位验证码");
      return;
    }
    if (newPassword !== confirmPassword) {
      setMessage("两次输入的新密码不一致");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/admin/security/password", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ currentPassword, currentCode, newPassword, confirmPassword }),
      });
      const result = (await response.json()) as ApiResult;
      if (!response.ok) {
        setMessage(result.error?.message ?? "修改密码失败，请重试");
        return;
      }
      window.location.replace("/admin");
    } catch {
      setMessage("网络连接失败，请稍后重试");
    } finally {
      setBusy(false);
    }
  }

  async function startTotp(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!/^\d{6}$/.test(currentCode)) {
      setMessage("请输入当前验证器显示的 6 位验证码");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/admin/security/totp", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ action: "start", currentPassword, currentCode }),
      });
      const result = (await response.json()) as TotpEnrollment & ApiResult;
      if (!response.ok) {
        setMessage(result.error?.message ?? "无法开始重新绑定");
        return;
      }
      const dataUrl = await QRCode.toDataURL(result.uri, {
        width: 360,
        margin: 0,
        errorCorrectionLevel: "M",
        color: { dark: "#1f2329", light: "#ffffff" },
      });
      setEnrollment(result);
      setQrDataUrl(dataUrl);
      setCurrentPassword("");
      setCurrentCode("");
    } catch {
      setMessage("网络连接失败，请稍后重试");
    } finally {
      setBusy(false);
    }
  }

  async function verifyTotp(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!/^\d{6}$/.test(newCode)) {
      setMessage("请输入新验证器显示的 6 位验证码");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/admin/security/totp", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ action: "verify", code: newCode }),
      });
      const result = (await response.json()) as ApiResult;
      if (!response.ok) {
        setMessage(result.error?.message ?? "验证码不正确，请重试");
        return;
      }
      window.location.replace("/admin");
    } catch {
      setMessage("网络连接失败，请稍后重试");
    } finally {
      setBusy(false);
    }
  }

  async function cancelTotp() {
    if (busy) return;
    if (!enrollment) {
      closeDialog();
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/admin/security/totp", { method: "DELETE" });
      if (!response.ok) {
        const result = (await response.json()) as ApiResult;
        setMessage(result.error?.message ?? "暂时无法取消，请稍后重试");
        return;
      }
      setEnrollment(null);
      setQrDataUrl("");
      setDialog(null);
    } catch {
      setMessage("网络连接失败，请稍后重试");
    } finally {
      setBusy(false);
    }
  }

  async function copySecret() {
    if (!enrollment) return;
    try {
      await navigator.clipboard.writeText(enrollment.secret);
      setMessage("设置密钥已复制");
    } catch {
      setMessage("复制失败，请手动选择设置密钥");
    }
  }

  return (
    <AdminShell username={username} active="settings">
      <section className="admin-overview-main admin-settings-main" aria-labelledby="settings-title">
        <p className="admin-overview-kicker">设置</p>
        <h1 id="settings-title">后台设置</h1>
        <p className="admin-overview-subtitle">管理后台账号与安全选项</p>

        <section className="admin-settings-card" aria-labelledby="account-security-title">
          <h2 id="account-security-title">账号安全</h2>
          <div className="admin-settings-row">
            <span className="admin-settings-row-icon password" aria-hidden="true">
              <span className="admin-settings-lock" />
            </span>
            <div className="admin-settings-row-copy">
              <h3>登录密码</h3>
              <p>用于后台账号登录</p>
            </div>
            <button type="button" onClick={() => openDialog("password")}>修改密码</button>
          </div>
          <div className="admin-settings-row">
            <span className="admin-settings-row-icon totp" aria-hidden="true">
              <AdminCssIcon name="shield" />
            </span>
            <div className="admin-settings-row-copy">
              <h3>双重验证</h3>
              <p>Microsoft Authenticator</p>
            </div>
            <span className="admin-settings-status">已启用</span>
            <button type="button" onClick={() => openDialog("totp")}>重新绑定</button>
          </div>
        </section>

        <p className="admin-overview-privacy admin-settings-privacy">
          <span className="admin-overview-lock" aria-hidden="true" />
          修改安全设置会要求再次验证身份并记录审计事件
        </p>
      </section>

      {dialog === "password" && (
        <div className="admin-accounts-dialog-backdrop">
          <section className="admin-accounts-dialog admin-settings-dialog" role="dialog" aria-modal="true" aria-labelledby="password-dialog-title">
            <header>
              <div>
                <h2 id="password-dialog-title">修改登录密码</h2>
                <p>完成二次验证后，所有后台设备都需要重新登录</p>
              </div>
              <button type="button" onClick={closeDialog} disabled={busy} aria-label="关闭">×</button>
            </header>
            <form onSubmit={changePassword}>
              <label>
                当前密码
                <input type="password" value={currentPassword} onChange={(event) => setCurrentPassword(event.target.value)} autoComplete="current-password" maxLength={128} required autoFocus />
              </label>
              <label>
                当前动态验证码
                <input value={currentCode} onChange={(event) => setCurrentCode(digits(event.target.value))} autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} placeholder="6 位验证码" required />
              </label>
              <label>
                新密码
                <input type="password" value={newPassword} onChange={(event) => setNewPassword(event.target.value)} autoComplete="new-password" minLength={12} maxLength={128} required />
              </label>
              <label>
                确认新密码
                <input type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} autoComplete="new-password" minLength={12} maxLength={128} required />
              </label>
              <p className="admin-accounts-dialog-help">至少 12 位，并同时包含大小写字母、数字和符号。</p>
              {message && <p className="admin-accounts-dialog-error" role="alert">{message}</p>}
              <footer>
                <button type="button" onClick={closeDialog} disabled={busy}>取消</button>
                <button className="admin-accounts-primary" disabled={busy}>{busy ? "修改中…" : "确认修改"}</button>
              </footer>
            </form>
          </section>
        </div>
      )}

      {dialog === "totp" && (
        <div className="admin-accounts-dialog-backdrop">
          <section className="admin-accounts-dialog admin-settings-dialog" role="dialog" aria-modal="true" aria-labelledby="totp-dialog-title">
            <header>
              <div>
                <h2 id="totp-dialog-title">重新绑定双重验证</h2>
                <p>{enrollment ? "使用 Microsoft Authenticator 扫描新二维码" : "先验证当前账号身份"}</p>
              </div>
              <button type="button" onClick={() => void cancelTotp()} disabled={busy} aria-label="关闭">×</button>
            </header>
            {!enrollment ? (
              <form onSubmit={startTotp}>
                <label>
                  当前密码
                  <input type="password" value={currentPassword} onChange={(event) => setCurrentPassword(event.target.value)} autoComplete="current-password" maxLength={128} required autoFocus />
                </label>
                <label>
                  当前动态验证码
                  <input value={currentCode} onChange={(event) => setCurrentCode(digits(event.target.value))} autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} placeholder="6 位验证码" required />
                </label>
                <p className="admin-accounts-dialog-help">旧验证器会一直有效，直到新验证器通过校验。</p>
                {message && <p className="admin-accounts-dialog-error" role="alert">{message}</p>}
                <footer>
                  <button type="button" onClick={closeDialog} disabled={busy}>取消</button>
                  <button className="admin-accounts-primary" disabled={busy}>{busy ? "验证中…" : "继续"}</button>
                </footer>
              </form>
            ) : (
              <form onSubmit={verifyTotp}>
                <div className="admin-settings-qr" aria-busy={!qrDataUrl}>
                  {qrDataUrl ? <img src={qrDataUrl} width="176" height="176" alt="新的 Microsoft Authenticator 绑定二维码" /> : <span>正在生成二维码…</span>}
                </div>
                <button className="admin-settings-secret-toggle" type="button" onClick={() => setShowSecret((value) => !value)} aria-expanded={showSecret}>
                  无法扫码？使用设置密钥
                </button>
                {showSecret && (
                  <div className="admin-auth-secret admin-settings-secret">
                    <code>{enrollment.secret.match(/.{1,4}/g)?.join(" ")}</code>
                    <button type="button" onClick={copySecret}>复制</button>
                  </div>
                )}
                <label>
                  新验证器动态验证码
                  <input value={newCode} onChange={(event) => setNewCode(digits(event.target.value))} autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} placeholder="6 位验证码" required autoFocus />
                </label>
                <p className="admin-accounts-dialog-help">绑定信息将在 10 分钟后失效；成功后所有后台设备需要重新登录。</p>
                {message && <p className="admin-accounts-dialog-error" role="alert">{message}</p>}
                <footer>
                  <button type="button" onClick={() => void cancelTotp()} disabled={busy}>取消绑定</button>
                  <button className="admin-accounts-primary" disabled={busy}>{busy ? "绑定中…" : "验证并绑定"}</button>
                </footer>
              </form>
            )}
          </section>
        </div>
      )}
    </AdminShell>
  );
}

function digits(value: string): string {
  return value.replace(/\D/g, "").slice(0, 6);
}
