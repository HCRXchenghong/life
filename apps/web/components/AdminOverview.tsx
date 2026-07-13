"use client";

import Link from "next/link";
import { useState } from "react";

export function AdminOverview({
  username,
  aiProviderCount,
}: {
  username: string;
  aiProviderCount: number;
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
          <AdminNavItem href="/admin" label="概览" icon="grid" active />
          <AdminNavItem href="/admin/accounts" label="App 账号" icon="user" />
          <AdminNavItem href="/admin/ai" label="AI 配置" icon="ai" />
          <AdminNavItem href="/admin/audit" label="安全审计" icon="shield" />
          <AdminNavItem href="/admin/settings" label="设置" icon="settings" />
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

      <section className="admin-overview-main" aria-labelledby="overview-title">
        <p className="admin-overview-kicker">概览</p>
        <h1 id="overview-title">开始使用 Daylink</h1>
        <p className="admin-overview-subtitle">完成以下配置后，即可邀请成员使用 App</p>

        <div className="admin-overview-setup">
          <OverviewAction
            href="/admin/accounts"
            icon="user"
            title="App 账号"
            detail="尚未创建账号"
            action="创建账号"
            primary
          />
          <OverviewAction
            href="/admin/ai"
            icon="ai"
            title="AI 服务"
            detail={aiProviderCount > 0 ? `已配置 ${aiProviderCount} 个服务` : "尚未配置 API 与模型"}
            action={aiProviderCount > 0 ? "管理配置" : "去配置"}
          />
        </div>

        <p className="admin-overview-privacy">
          <span className="admin-overview-lock" aria-hidden="true" />
          管理员无法读取用户的端到端加密内容
        </p>
      </section>
    </main>
  );
}

function AdminNavItem({
  href,
  label,
  icon,
  active = false,
}: {
  href: string;
  label: string;
  icon: IconName;
  active?: boolean;
}) {
  return (
    <Link href={href} className={active ? "active" : ""} aria-current={active ? "page" : undefined}>
      <CssIcon name={icon} />
      <span>{label}</span>
    </Link>
  );
}

function OverviewAction({
  href,
  icon,
  title,
  detail,
  action,
  primary = false,
}: {
  href: string;
  icon: IconName;
  title: string;
  detail: string;
  action: string;
  primary?: boolean;
}) {
  return (
    <article className="admin-overview-action">
      <span className={`admin-overview-action-icon ${icon}`}><CssIcon name={icon} /></span>
      <div><h2>{title}</h2><p>{detail}</p></div>
      <Link href={href} className={primary ? "primary" : ""}>{action}<span aria-hidden="true">›</span></Link>
    </article>
  );
}

type IconName = "grid" | "user" | "ai" | "shield" | "settings";

function CssIcon({ name }: { name: IconName }) {
  return <span className={`admin-css-icon ${name}`} aria-hidden="true" />;
}
