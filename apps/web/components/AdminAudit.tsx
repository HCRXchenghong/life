"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { AdminCssIcon, AdminShell } from "./AdminShell";

type AuditEvent = {
  id: string;
  title: string;
  actor: string;
  outcome: "allowed" | "denied" | "failed";
  risk: "read_only" | "low" | "medium" | "high" | "critical";
  createdAt: string;
};

export function AdminAudit({
  username,
  events,
}: {
  username: string;
  events: AuditEvent[];
}) {
  const router = useRouter();
  const [refreshing, startRefresh] = useTransition();

  return (
    <AdminShell username={username} active="audit">
      <section className="admin-overview-main admin-audit-main" aria-labelledby="audit-title">
        <p className="admin-overview-kicker">安全审计</p>
        <header className="admin-accounts-heading admin-audit-heading">
          <div>
            <h1 id="audit-title">安全事件</h1>
            <p className="admin-overview-subtitle">查看后台与账号的关键安全操作</p>
          </div>
          <button
            className="admin-audit-refresh"
            type="button"
            disabled={refreshing}
            onClick={() => startRefresh(() => router.refresh())}
          >
            <span aria-hidden="true">↻</span>
            {refreshing ? "刷新中…" : "刷新"}
          </button>
        </header>

        {events.length === 0 ? (
          <section className="admin-accounts-empty admin-audit-empty" aria-label="暂无安全事件">
            <span className="admin-audit-empty-icon"><AdminCssIcon name="shield" /></span>
            <h2>暂无安全事件</h2>
            <p>登录、密码重置与敏感配置变更会记录在这里</p>
          </section>
        ) : (
          <section className="admin-audit-list" aria-label="最近的安全事件">
            {events.map((event) => (
              <article className="admin-audit-row" key={event.id}>
                <span className={`admin-audit-row-icon ${event.outcome}`} aria-hidden="true">
                  <AdminCssIcon name="shield" />
                </span>
                <div className="admin-audit-row-copy">
                  <h2>{event.title}</h2>
                  <p>{event.actor} · {formatDateTime(event.createdAt)}</p>
                </div>
                <span className={`admin-audit-outcome ${event.outcome}`}>
                  {outcomeLabel(event.outcome)}
                </span>
                <span className={`admin-audit-risk ${event.risk}`}>{riskLabel(event.risk)}</span>
              </article>
            ))}
          </section>
        )}

        <p className="admin-overview-privacy admin-accounts-privacy">
          <span className="admin-overview-lock" aria-hidden="true" />
          审计记录不包含密码、API Key 或用户内容
        </p>
      </section>
    </AdminShell>
  );
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat("zh-CN", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(value));
}

function outcomeLabel(outcome: AuditEvent["outcome"]): string {
  if (outcome === "allowed") return "成功";
  if (outcome === "denied") return "已拒绝";
  return "失败";
}

function riskLabel(risk: AuditEvent["risk"]): string {
  if (risk === "critical") return "严重";
  if (risk === "high") return "高风险";
  if (risk === "medium") return "中风险";
  return "低风险";
}
