import Link from "next/link";
import { AdminCssIcon, AdminIconName, AdminShell } from "./AdminShell";

export function AdminOverview({
  username,
  aiProviderCount,
  appAccountCount,
}: {
  username: string;
  aiProviderCount: number;
  appAccountCount: number;
}) {
  return (
    <AdminShell username={username} active="overview">
      <section className="admin-overview-main" aria-labelledby="overview-title">
        <p className="admin-overview-kicker">概览</p>
        <h1 id="overview-title">开始使用 Daylink</h1>
        <p className="admin-overview-subtitle">完成以下配置后，即可邀请成员使用 App</p>

        <div className="admin-overview-setup">
          <OverviewAction
            href="/admin/accounts"
            icon="user"
            title="App 账号"
            detail={appAccountCount > 0 ? `已创建 ${appAccountCount} 个账号` : "尚未创建账号"}
            action={appAccountCount > 0 ? "管理账号" : "创建账号"}
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
    </AdminShell>
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
  icon: AdminIconName;
  title: string;
  detail: string;
  action: string;
  primary?: boolean;
}) {
  return (
    <article className="admin-overview-action">
      <span className={`admin-overview-action-icon ${icon}`}><AdminCssIcon name={icon} /></span>
      <div><h2>{title}</h2><p>{detail}</p></div>
      <Link href={href} className={primary ? "primary" : ""}>{action}<span aria-hidden="true">›</span></Link>
    </article>
  );
}
