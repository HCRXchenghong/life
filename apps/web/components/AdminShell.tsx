"use client";

import Link from "next/link";
import { ReactNode, useState } from "react";

export type AdminSection = "overview" | "accounts" | "ai" | "audit" | "settings";
export type AdminIconName = "grid" | "user" | "ai" | "shield" | "settings";

export function AdminShell({
  username,
  active,
  children,
}: {
  username: string;
  active: AdminSection;
  children: ReactNode;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);

  async function logout() {
    if (loggingOut) return;
    setLoggingOut(true);
    try {
      const response = await fetch("/api/auth/logout", { method: "POST" });
      if (!response.ok) throw new Error();
      window.location.replace("/admin");
    } catch {
      setLoggingOut(false);
    }
  }

  return (
    <main className="admin-overview-shell">
      <aside className="admin-overview-sidebar">
        <Link className="admin-overview-brand" href="/" aria-label="Daylink 首页">
          <span className="admin-auth-brand-mark" aria-hidden="true" />
          <span>Daylink</span>
        </Link>

        <nav className="admin-overview-nav" aria-label="后台导航">
          <AdminNavItem href="/admin" label="概览" icon="grid" active={active === "overview"} />
          <AdminNavItem href="/admin/accounts" label="App 账号" icon="user" active={active === "accounts"} />
          <AdminNavItem href="/admin/ai" label="AI 配置" icon="ai" active={active === "ai"} />
          <AdminNavItem href="/admin/audit" label="安全审计" icon="shield" active={active === "audit"} />
          <AdminNavItem href="/admin/settings" label="设置" icon="settings" active={active === "settings"} />
        </nav>

        <div className="admin-overview-account">
          <span className="admin-overview-avatar" aria-hidden="true">
            {username.slice(0, 1).toUpperCase()}
          </span>
          <strong title={username}>{username}</strong>
          <button
            type="button"
            aria-label="打开管理员菜单"
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((value) => !value)}
          >
            ⋮
          </button>
          {menuOpen && (
            <div className="admin-overview-account-menu">
              <button type="button" onClick={logout} disabled={loggingOut}>
                {loggingOut ? "正在退出…" : "退出登录"}
              </button>
            </div>
          )}
        </div>
      </aside>
      {children}
    </main>
  );
}

function AdminNavItem({
  href,
  label,
  icon,
  active,
}: {
  href: string;
  label: string;
  icon: AdminIconName;
  active: boolean;
}) {
  return (
    <Link href={href} className={active ? "active" : ""} aria-current={active ? "page" : undefined}>
      <AdminCssIcon name={icon} />
      <span>{label}</span>
    </Link>
  );
}

export function AdminCssIcon({ name }: { name: AdminIconName }) {
  return <span className={`admin-css-icon ${name}`} aria-hidden="true" />;
}
