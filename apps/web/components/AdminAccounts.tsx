"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { AdminCssIcon, AdminShell } from "./AdminShell";

type AppAccount = {
  id: string;
  username: string;
  status: "active" | "disabled";
  passwordChangeRequired: boolean;
  lockedUntil: string | null;
  lastLoginAt: string | null;
  createdAt: string;
};

type DialogState =
  | { kind: "create" }
  | { kind: "reset"; account: AppAccount }
  | null;

export function AdminAccounts({
  username,
  accounts,
}: {
  username: string;
  accounts: AppAccount[];
}) {
  const router = useRouter();
  const [dialog, setDialog] = useState<DialogState>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!dialog) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !busy) setDialog(null);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [dialog, busy]);

  function openDialog(next: Exclude<DialogState, null>) {
    setError("");
    setNotice("");
    setDialog(next);
  }

  async function saveCredentials(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!dialog) return;
    setError("");
    setBusy(dialog.kind);
    const form = new FormData(event.currentTarget);
    const body = dialog.kind === "create"
      ? {
          username: form.get("username"),
          password: form.get("password"),
          confirmPassword: form.get("confirmPassword"),
        }
      : {
          id: dialog.account.id,
          action: "reset_password",
          password: form.get("password"),
          confirmPassword: form.get("confirmPassword"),
        };
    const response = await fetch("/api/admin/app-accounts", {
      method: dialog.kind === "create" ? "POST" : "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    if (!response.ok) {
      setError(result.error?.message ?? "保存失败，请稍后重试");
      return;
    }
    setNotice(dialog.kind === "create" ? "App 账号已创建" : "密码已重置，所有旧设备已退出登录");
    setDialog(null);
    router.refresh();
  }

  async function changeStatus(account: AppAccount) {
    const action = account.status === "active" ? "disable" : "enable";
    if (action === "disable" && !window.confirm(`停用 ${account.username}？该账号的所有设备会立即退出登录。`)) {
      return;
    }
    setError("");
    setNotice("");
    setBusy(`${action}:${account.id}`);
    const response = await fetch("/api/admin/app-accounts", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ id: account.id, action }),
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    if (!response.ok) {
      setError(result.error?.message ?? "操作失败，请稍后重试");
      return;
    }
    setNotice(action === "disable" ? "账号已停用" : "账号已启用");
    router.refresh();
  }

  return (
    <AdminShell username={username} active="accounts">
      <section className="admin-overview-main admin-accounts-main" aria-labelledby="accounts-title">
        <p className="admin-overview-kicker">App 账号</p>
        <header className="admin-accounts-heading">
          <div>
            <h1 id="accounts-title">成员账号</h1>
            <p className="admin-overview-subtitle">创建并管理成员的 App 登录账号</p>
          </div>
          <button className="admin-accounts-primary" type="button" onClick={() => openDialog({ kind: "create" })}>
            创建账号
          </button>
        </header>

        {notice && <p className="admin-accounts-notice" role="status">{notice}</p>}
        {error && <p className="admin-accounts-error" role="alert">{error}</p>}

        {accounts.length === 0 ? (
          <section className="admin-accounts-empty" aria-label="暂无 App 账号">
            <span className="admin-accounts-empty-icon"><AdminCssIcon name="user" /></span>
            <h2>暂无 App 账号</h2>
            <p>创建账号后，成员可在新设备登录并同步加密数据</p>
            <button className="admin-accounts-primary" type="button" onClick={() => openDialog({ kind: "create" })}>
              创建账号
            </button>
          </section>
        ) : (
          <section className="admin-accounts-list" aria-label="App 账号列表">
            {accounts.map((account) => {
              const locked = Boolean(account.lockedUntil && new Date(account.lockedUntil) > new Date());
              return (
                <article key={account.id} className="admin-accounts-row">
                  <span className="admin-accounts-row-avatar" aria-hidden="true">
                    {account.username.slice(0, 1).toUpperCase()}
                  </span>
                  <div className="admin-accounts-row-copy">
                    <h2>{account.username}</h2>
                    <p>
                      {account.status === "disabled"
                        ? "已停用"
                        : locked
                          ? "登录已临时锁定"
                          : account.passwordChangeRequired
                            ? "等待成员修改初始密码"
                            : account.lastLoginAt
                              ? `最近登录 ${formatDate(account.lastLoginAt)}`
                              : "尚未登录"}
                    </p>
                  </div>
                  <span className={`admin-accounts-status ${account.status}`}>
                    {account.status === "active" ? "正常" : "已停用"}
                  </span>
                  <div className="admin-accounts-actions">
                    <button type="button" onClick={() => openDialog({ kind: "reset", account })}>
                      重置密码
                    </button>
                    <button
                      type="button"
                      className={account.status === "active" ? "danger" : ""}
                      disabled={busy === `disable:${account.id}` || busy === `enable:${account.id}`}
                      onClick={() => changeStatus(account)}
                    >
                      {account.status === "active" ? "停用" : "启用"}
                    </button>
                  </div>
                </article>
              );
            })}
          </section>
        )}

        <p className="admin-overview-privacy admin-accounts-privacy">
          <span className="admin-overview-lock" aria-hidden="true" />
          后台只管理登录状态，无法读取账号内的加密内容
        </p>
      </section>

      {dialog && (
        <div className="admin-accounts-dialog-backdrop" onMouseDown={(event) => {
          if (event.target === event.currentTarget && !busy) setDialog(null);
        }}>
          <section className="admin-accounts-dialog" role="dialog" aria-modal="true" aria-labelledby="account-dialog-title">
            <header>
              <div>
                <h2 id="account-dialog-title">
                  {dialog.kind === "create" ? "创建 App 账号" : `重置 ${dialog.account.username} 的密码`}
                </h2>
                <p>密码只用于登录验证，后台不会保存可恢复明文</p>
              </div>
              <button type="button" aria-label="关闭" disabled={Boolean(busy)} onClick={() => setDialog(null)}>×</button>
            </header>
            <form onSubmit={saveCredentials}>
              {dialog.kind === "create" && (
                <label>
                  App 账号
                  <input
                    name="username"
                    autoFocus
                    required
                    minLength={4}
                    maxLength={32}
                    autoComplete="off"
                    placeholder="例如 chenghong"
                    pattern="[A-Za-z0-9][A-Za-z0-9._-]{3,31}"
                  />
                </label>
              )}
              <label>
                {dialog.kind === "create" ? "初始密码" : "新密码"}
                <input
                  name="password"
                  type="password"
                  autoFocus={dialog.kind === "reset"}
                  required
                  minLength={12}
                  maxLength={128}
                  autoComplete="new-password"
                  placeholder="至少 12 位，包含大小写、数字和符号"
                />
              </label>
              <label>
                确认密码
                <input
                  name="confirmPassword"
                  type="password"
                  required
                  minLength={12}
                  maxLength={128}
                  autoComplete="new-password"
                />
              </label>
              <p className="admin-accounts-dialog-help">成员首次登录后必须修改初始密码；重置密码会撤销全部旧设备会话。</p>
              {error && <p className="admin-accounts-dialog-error" role="alert">{error}</p>}
              <footer>
                <button type="button" disabled={Boolean(busy)} onClick={() => setDialog(null)}>取消</button>
                <button className="admin-accounts-primary" disabled={Boolean(busy)}>
                  {busy ? "正在保存…" : dialog.kind === "create" ? "创建账号" : "确认重置"}
                </button>
              </footer>
            </form>
          </section>
        </div>
      )}
    </AdminShell>
  );
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(value));
}
