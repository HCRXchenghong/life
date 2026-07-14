import type { Metadata } from "next";
import { desc, inArray } from "drizzle-orm";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { AdminAudit } from "../../../components/AdminAudit";
import { getDb } from "../../../db";
import { adminAccounts, appAccounts, auditEvents } from "../../../db/schema";
import { getAdminIdentity } from "../../../lib/admin-auth";

export const metadata: Metadata = { title: "安全审计" };
export const dynamic = "force-dynamic";

const SECURITY_ACTIONS = [
  "admin.enrollment.cancelled",
  "admin.enrollment.started",
  "admin.enrollment.verify",
  "admin.enrollment.completed",
  "admin.login",
  "admin.logout",
  "admin.password.change",
  "admin.totp.rebind_started",
  "admin.totp.rebind_cancelled",
  "admin.totp.rebound",
  "app.login",
  "app.logout",
  "app.password.change",
  "app_account.create",
  "app_account.enable",
  "app_account.disable",
  "app_account.reset_password",
  "mobile_token.create",
  "mobile_token.revoke",
  "ai_provider.create",
  "ai_provider.update",
] as const;

export default async function AdminAuditPage() {
  const requestHeaders = await headers();
  const identity = await getAdminIdentity(
    requestHeaders.get("cookie"),
    requestHeaders.get("user-agent"),
  );
  if (!identity) redirect("/admin");

  const rows = await getDb()
    .select({
      id: auditEvents.id,
      actor: auditEvents.actor,
      action: auditEvents.action,
      outcome: auditEvents.outcome,
      risk: auditEvents.risk,
      createdAt: auditEvents.createdAt,
    })
    .from(auditEvents)
    .where(inArray(auditEvents.action, [...SECURITY_ACTIONS]))
    .orderBy(desc(auditEvents.createdAt), desc(auditEvents.id))
    .limit(50);

  const appActorIds = Array.from(
    new Set(
      rows
        .map((row) => actorId(row.actor, "app"))
        .filter((value): value is string => Boolean(value && value !== "unknown")),
    ),
  );
  const adminActorIds = Array.from(
    new Set(
      rows
        .map((row) => actorId(row.actor, "admin"))
        .filter((value): value is string => Boolean(value && value !== "unknown")),
    ),
  );
  const [appActors, adminActors] = await Promise.all([
    appActorIds.length
      ? getDb()
          .select({ id: appAccounts.id, username: appAccounts.username })
          .from(appAccounts)
          .where(inArray(appAccounts.id, appActorIds))
      : [],
    adminActorIds.length
      ? getDb()
          .select({ id: adminAccounts.id, username: adminAccounts.username })
          .from(adminAccounts)
          .where(inArray(adminAccounts.id, adminActorIds))
      : [],
  ]);
  const actorNames = new Map([
    ...appActors.map((actor) => [`app:${actor.id}`, `App 账号 ${actor.username}`] as const),
    ...adminActors.map((actor) => [`admin:${actor.id}`, `管理员 ${actor.username}`] as const),
  ]);

  return (
    <AdminAudit
      username={identity.username}
      events={rows.map((row) => ({
        id: row.id,
        title: actionTitle(row.action),
        actor: actorLabel(row.actor, actorNames),
        outcome: row.outcome,
        risk: row.risk,
        createdAt: row.createdAt,
      }))}
    />
  );
}

function actorId(actor: string, kind: "admin" | "app"): string | null {
  const prefix = `${kind}:`;
  return actor.startsWith(prefix) ? actor.slice(prefix.length) : null;
}

function actorLabel(actor: string, names: ReadonlyMap<string, string>): string {
  const known = names.get(actor);
  if (known) return known;
  if (actor === "admin:unknown") return "未知管理员";
  if (actor === "app:unknown") return "未知 App 账号";
  if (actor.startsWith("bootstrap:") || actor === "system:bootstrap") return "系统初始化";
  if (actor.startsWith("admin:")) return "后台管理员";
  if (actor.startsWith("app:")) return "App 账号";
  return "系统";
}

function actionTitle(action: string): string {
  const labels: Record<string, string> = {
    "admin.enrollment.cancelled": "取消后台双重验证配置",
    "admin.enrollment.started": "开始后台双重验证配置",
    "admin.enrollment.verify": "验证后台双重验证码",
    "admin.enrollment.completed": "完成后台双重验证配置",
    "admin.login": "后台登录",
    "admin.logout": "后台退出登录",
    "admin.password.change": "修改后台登录密码",
    "admin.totp.rebind_started": "开始重新绑定后台双重验证",
    "admin.totp.rebind_cancelled": "取消重新绑定后台双重验证",
    "admin.totp.rebound": "完成重新绑定后台双重验证",
    "app.login": "App 账号登录",
    "app.logout": "App 账号退出登录",
    "app.password.change": "App 账号修改密码",
    "app_account.create": "创建 App 账号",
    "app_account.enable": "启用 App 账号",
    "app_account.disable": "停用 App 账号",
    "app_account.reset_password": "重置 App 账号密码",
    "mobile_token.create": "创建设备令牌",
    "mobile_token.revoke": "撤销设备令牌",
    "ai_provider.create": "添加 AI 服务",
    "ai_provider.update": "修改 AI 服务配置",
  };
  return labels[action] ?? "安全操作";
}
