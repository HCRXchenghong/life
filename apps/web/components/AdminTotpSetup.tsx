"use client";
/* eslint-disable @next/next/no-img-element -- QR data URL is generated locally and never leaves the browser */

import Link from "next/link";
import QRCode from "qrcode";
import { FormEvent, useEffect, useState } from "react";

type Enrollment = {
  username: string;
  secret: string;
  uri: string;
  expiresAt: string;
};

type ApiResult = {
  next?: string;
  error?: { message?: string };
};

export function AdminTotpSetup() {
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState("");
  const [showSecret, setShowSecret] = useState(false);
  const [code, setCode] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;
    fetch("/api/auth/setup/enrollment", { cache: "no-store" })
      .then(async (response) => {
        const payload = (await response.json()) as Enrollment & ApiResult;
        if (!response.ok) throw new Error(payload.error?.message ?? "初始化会话已失效");
        const dataUrl = await QRCode.toDataURL(payload.uri, {
          width: 368,
          margin: 0,
          errorCorrectionLevel: "M",
          color: { dark: "#111111", light: "#FFFFFF" },
        });
        if (!active) return;
        setEnrollment(payload);
        setQrDataUrl(dataUrl);
      })
      .catch((error: unknown) => {
        if (active) setMessage(error instanceof Error ? error.message : "无法加载二维码");
      });
    return () => {
      active = false;
    };
  }, []);

  async function verify(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!/^\d{6}$/.test(code)) {
      setMessage("请输入 6 位验证码");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/auth/setup/verify", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ code }),
      });
      const result = (await response.json()) as ApiResult;
      if (!response.ok) {
        setMessage(result.error?.message ?? "验证失败，请重新输入");
        return;
      }
      window.location.replace(result.next ?? "/admin");
    } catch {
      setMessage("网络连接失败，请稍后重试");
    } finally {
      setBusy(false);
    }
  }

  async function restart() {
    if (busy) return;
    setBusy(true);
    try {
      const response = await fetch("/api/auth/setup", { method: "DELETE" });
      if (!response.ok) throw new Error();
      window.location.replace("/admin");
    } catch {
      setMessage("暂时无法返回，请稍后重试");
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
    <main className="admin-auth-shell">
      <Link className="admin-auth-brand" href="/" aria-label="Daylink 首页">
        <span className="admin-auth-brand-mark" aria-hidden="true" />
        <span>Daylink</span>
      </Link>

      <section className="admin-auth-content admin-auth-totp-content" aria-labelledby="totp-title">
        <h1 id="totp-title">绑定双重验证</h1>
        <p className="admin-auth-subtitle">使用 Microsoft Authenticator 扫描二维码</p>

        <div className="admin-auth-qr" aria-busy={!qrDataUrl}>
          {qrDataUrl ? (
            <img src={qrDataUrl} width="184" height="184" alt="Microsoft Authenticator 绑定二维码" />
          ) : (
            <span>{message ? "二维码加载失败" : "正在生成二维码…"}</span>
          )}
        </div>

        <button
          type="button"
          className="admin-auth-secret-toggle"
          onClick={() => setShowSecret((value) => !value)}
          disabled={!enrollment}
          aria-expanded={showSecret}
        >
          无法扫码？使用设置密钥
        </button>

        {showSecret && enrollment && (
          <div className="admin-auth-secret" role="group" aria-label="手动设置密钥">
            <code>{enrollment.secret.match(/.{1,4}/g)?.join(" ")}</code>
            <button type="button" onClick={copySecret}>复制</button>
          </div>
        )}

        <form className="admin-auth-form admin-auth-totp-form" onSubmit={verify}>
          <label>
            <span>动态验证码</span>
            <input
              name="code"
              value={code}
              onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
              autoComplete="one-time-code"
              inputMode="numeric"
              pattern="[0-9]{6}"
              maxLength={6}
              placeholder="请输入 6 位验证码"
              required
              autoFocus
            />
          </label>
          <button className="admin-auth-primary" disabled={busy || !enrollment}>
            {busy ? "验证中…" : "验证并进入后台"}
          </button>
          <button className="admin-auth-back" type="button" onClick={restart} disabled={busy}>
            返回上一步
          </button>
          <p className="admin-auth-message" role="status">{message}</p>
        </form>
      </section>

      <p className="admin-auth-privacy">验证成功前，管理员账号不会启用</p>
    </main>
  );
}
