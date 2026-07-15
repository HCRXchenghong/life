import QRCode from "qrcode";
import { FormEvent, ReactNode, useCallback, useEffect, useState } from "react";
import { api, navigate } from "./api";

type Props = { username: string; path: string; onLogout: () => void };

export function Dashboard({ username, path, onLogout }: Props) {
  const active = section(path);

  useEffect(() => {
    if (path.includes("/ai")) navigate("/admin/settings");
  }, [path]);

  async function logout() {
    await api("/api/auth/logout", { method: "POST" });
    onLogout();
  }

  return (
    <main className="admin-overview-shell">
      <aside className="admin-overview-sidebar">
        <div className="admin-overview-sidebar-head">
          <NavLink href="/admin" className="admin-overview-brand">
            <span className="admin-auth-brand-mark" />
            <span>Daylink</span>
          </NavLink>
          <span className="admin-overview-product">管理后台</span>
        </div>
        <nav className="admin-overview-nav" aria-label="后台导航">
          <NavLink href="/admin" active={active === "overview"}>概览</NavLink>
          <NavLink href="/admin/accounts" active={active === "accounts"}>App 账号</NavLink>
          <NavLink href="/admin/audit" active={active === "audit"}>安全审计</NavLink>
          <NavLink href="/admin/settings" active={active === "settings"}>设置</NavLink>
        </nav>
        <div className="admin-overview-account">
          <span className="admin-overview-avatar">{username.slice(0, 1).toUpperCase()}</span>
          <strong>{username}</strong>
          <button onClick={() => void logout()}>退出</button>
        </div>
      </aside>
      {active === "overview" && <Overview />}
      {active === "accounts" && <Accounts />}
      {active === "audit" && <Audit />}
      {active === "settings" && <Settings />}
    </main>
  );
}

function NavLink({ href, children, active, className = "" }: { href: string; children: ReactNode; active?: boolean; className?: string }) {
  return <a href={href} className={`${className} ${active ? "active" : ""}`} onClick={(event) => { event.preventDefault(); navigate(href); }}>{children}</a>;
}

function section(path: string) {
  if (path.includes("/accounts")) return "accounts";
  if (path.includes("/audit")) return "audit";
  if (path.includes("/settings") || path.includes("/ai")) return "settings";
  return "overview";
}

function Page({ kicker, title, subtitle, action, children }: { kicker: string; title: string; subtitle: string; action?: ReactNode; children: ReactNode }) {
  return (
    <section className="admin-overview-main">
      <header className="admin-page-header">
        <div>
          <p className="admin-overview-kicker">{kicker}</p>
          <h1>{title}</h1>
          <p className="admin-overview-subtitle">{subtitle}</p>
        </div>
        {action && <div className="admin-page-action">{action}</div>}
      </header>
      {children}
    </section>
  );
}

function Overview() {
  const [data, setData] = useState<OverviewData | null>(null);
  const load = useCallback(() => api<OverviewData>("/api/admin/overview").then(setData), []);
  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(), 30_000);
    return () => window.clearInterval(timer);
  }, [load]);
  return (
    <Page kicker="概览" title="开始使用 Daylink" subtitle="账号与部署服务器运行状态">
      <div className="admin-overview-setup">
        <Action title="App 账号" detail={`已创建 ${data?.appAccountCount ?? 0} 个账号`} href="/admin/accounts" />
        <Action title="AI 服务" detail={data?.aiProviderCount ? "已配置" : "尚未配置"} href="/admin/settings" />
      </div>
      <section className="admin-server-section">
        <header>
          <div><h2>服务器状态</h2><p>每 30 秒自动更新 · 支持 Windows、macOS 和 Ubuntu</p></div>
          <button className="admin-audit-refresh" onClick={() => void load()}>刷新数据</button>
        </header>
        <div className="admin-server-list">
          {data?.servers.map((server) => <ServerCard server={server} key={server.id} />) ?? <div className="admin-server-loading">正在读取服务器状态…</div>}
        </div>
      </section>
    </Page>
  );
}

type ServerMetrics = {
  id: string; name: string; hostname: string; system: string; systemLabel: string; architecture: string; status: string;
  cpuPercent: number; memoryPercent: number; memoryUsedBytes: number; memoryTotalBytes: number;
  diskPercent: number; diskUsedBytes: number; diskTotalBytes: number; databasePercent: number;
  databaseUsedBytes: number; databaseCapacityBytes: number; updatedAt: string;
};

type OverviewData = { appAccountCount: number; aiProviderCount: number; servers: ServerMetrics[] };

function ServerCard({ server }: { server: ServerMetrics }) {
  const metrics = [
    { label: "CPU", percent: server.cpuPercent, detail: `${server.cpuPercent.toFixed(1)}%` },
    { label: "运行内存", percent: server.memoryPercent, detail: `${formatBytes(server.memoryUsedBytes)} / ${formatBytes(server.memoryTotalBytes)}` },
    { label: "磁盘存储", percent: server.diskPercent, detail: `${formatBytes(server.diskUsedBytes)} / ${formatBytes(server.diskTotalBytes)}` },
    { label: "数据库占磁盘", percent: server.databasePercent, detail: formatBytes(server.databaseUsedBytes) },
  ];
  return (
    <article className="admin-server-card">
      <header>
        <div><h3>{server.name}</h3><p>{server.hostname} · {server.systemLabel} · {server.architecture}</p></div>
        <span className="admin-server-online">运行中</span>
      </header>
      <div className="admin-server-metrics">
        {metrics.map((metric) => <div className="admin-server-metric" key={metric.label}><div><span>{metric.label}</span><strong>{metric.percent.toFixed(1)}%</strong></div><div className="admin-server-track"><span style={{ width: `${Math.min(100, Math.max(0, metric.percent))}%` }} /></div><p>{metric.detail}</p></div>)}
      </div>
      <footer>更新于 {new Date(server.updatedAt).toLocaleString("zh-CN")}</footer>
    </article>
  );
}

function formatBytes(value: number) {
  if (!Number.isFinite(value) || value <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
  return `${(value / 1024 ** index).toFixed(index > 2 ? 1 : 0)} ${units[index]}`;
}

function Action({ title, detail, href }: { title: string; detail: string; href: string }) {
  return <article className="admin-overview-action"><div><h2>{title}</h2><p>{detail}</p></div><NavLink href={href}>管理<span>›</span></NavLink></article>;
}

type Subscription = { plan: "plus" | "pro" | "max"; cardType: "week" | "month" | "quarter" | "year"; startsAt: string; expiresAt: string; active: boolean };
type Account = { id: string; username: string; status: string; passwordChangeRequired: boolean; lockedUntil: string | null; lastLoginAt: string | null; createdAt: string; subscription: Subscription | null };
type AccountDialog = "choose" | "create" | "invite" | { type: "password" | "subscription"; account: Account } | null;
type Invitation = { path: string; code: string; expiresAt: string };

function Accounts() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [dialog, setDialog] = useState<AccountDialog>(null);
  const [invitation, setInvitation] = useState<Invitation | null>(null);
  const [message, setMessage] = useState("");
  const load = useCallback(() => api<{ accounts: Account[] }>("/api/admin/app-accounts").then((value) => setAccounts(value.accounts)), []);
  useEffect(() => { void load(); }, [load]);

  function closeDialog() {
    setDialog(null);
    setInvitation(null);
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.currentTarget));
    try {
      await api("/api/admin/app-accounts", { method: dialog === "create" ? "POST" : "PATCH", body: JSON.stringify(dialog === "create" ? values : { ...values, id: dialog && typeof dialog === "object" ? dialog.account.id : undefined, action: "reset_password" }) });
      closeDialog();
      setMessage("账号已保存");
      await load();
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "保存失败"); }
  }

  async function createInvitation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    try {
      const result = await api<{ invitation: Invitation }>("/api/admin/app-invitations", { method: "POST", body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))) });
      setInvitation(result.invitation);
      setMessage("");
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "邀请创建失败"); }
  }

  async function copyInvitation() {
    if (!invitation) return;
    try {
      await navigator.clipboard.writeText(new URL(invitation.path, window.location.origin).toString());
      setMessage("邀请链接已复制");
    } catch { setMessage("复制失败，请手动选择链接"); }
  }

  async function toggle(account: Account) {
    await api("/api/admin/app-accounts", { method: "PATCH", body: JSON.stringify({ id: account.id, action: account.status === "active" ? "disable" : "enable" }) });
    await load();
  }

  async function saveSubscription(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!dialog || typeof dialog !== "object" || dialog.type !== "subscription") return;
    const values = Object.fromEntries(new FormData(event.currentTarget));
    try {
      await api("/api/admin/app-subscriptions", {
        method: "POST",
        body: JSON.stringify({ accountId: dialog.account.id, action: "grant", ...values }),
      });
      closeDialog();
      setMessage("AI 套餐已更新");
      await load();
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "套餐保存失败"); }
  }

  async function revokeSubscription(account: Account) {
    try {
      await api("/api/admin/app-subscriptions", {
        method: "POST",
        body: JSON.stringify({ accountId: account.id, action: "revoke" }),
      });
      closeDialog();
      setMessage("AI 套餐已取消，远程 Agent 凭证已撤销");
      await load();
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "套餐取消失败"); }
  }

  return (
    <Page kicker="App 账号" title="成员账号" subtitle="管理登录状态、密码和一次性邀请" action={<button className="admin-accounts-primary" onClick={() => { setMessage(""); setDialog("choose"); }}>创建账号</button>}>
      {message && <p className="admin-accounts-notice">{message}</p>}
      <section className="admin-accounts-list">
        {accounts.length === 0 && <EmptyState title="还没有 App 账号" detail="创建账号后，成员即可登录并在不同设备间同步数据。" />}
        {accounts.map((account) => <article className="admin-accounts-row" key={account.id}><span className="admin-accounts-row-avatar">{account.username[0].toUpperCase()}</span><div className="admin-accounts-row-copy"><h2>{account.username}</h2><p>{account.passwordChangeRequired ? "等待修改初始密码" : account.lastLoginAt ? `最近登录 ${new Date(account.lastLoginAt).toLocaleString()}` : "尚未登录"}</p></div>{account.subscription?.active ? <span className={`admin-plan-badge ${account.subscription.plan}`}>{planName(account.subscription.plan)} · {new Date(account.subscription.expiresAt).toLocaleDateString("zh-CN")} 到期</span> : <span className="admin-plan-badge none">无套餐</span>}<span className={`admin-accounts-status ${account.status}`}>{account.status === "active" ? "正常" : "已停用"}</span><div className="admin-accounts-actions"><button onClick={() => setDialog({ type: "subscription", account })}>套餐</button><button onClick={() => setDialog({ type: "password", account })}>重置密码</button><button onClick={() => void toggle(account)}>{account.status === "active" ? "停用" : "启用"}</button></div></article>)}
      </section>
      {dialog === "choose" && <Dialog title="选择创建方式" onClose={closeDialog}><div className="admin-account-create-choices"><button onClick={() => setDialog("create")}><strong>手动创建</strong><span>管理员设置账号和初始密码</span></button><button onClick={() => setDialog("invite")}><strong>链接邀请</strong><span>成员通过一次性链接自行设置账号</span></button></div></Dialog>}
      {(dialog === "create" || (dialog && typeof dialog === "object" && dialog.type === "password")) && <Dialog title={dialog === "create" ? "创建 App 账号" : `重置 ${dialog.account.username} 的密码`} onClose={closeDialog}><form onSubmit={save}>{dialog === "create" && <label>App 账号<input name="username" minLength={4} maxLength={32} required autoFocus /></label>}<label>密码<input name="password" type="password" minLength={12} maxLength={128} required /></label><label>确认密码<input name="confirmPassword" type="password" minLength={12} maxLength={128} required /></label><footer><button type="button" onClick={closeDialog}>取消</button><button className="admin-accounts-primary">保存</button></footer></form></Dialog>}
      {dialog === "invite" && <Dialog title="链接邀请" onClose={closeDialog}>{!invitation ? <form onSubmit={createInvitation}><label>有效期<select name="validity" defaultValue="week"><option value="day">1 天</option><option value="week">1 周</option><option value="month">1 月</option></select></label><p className="admin-invite-hint">链接只能注册一个账号，成功注册后立即失效。</p><footer><button type="button" onClick={closeDialog}>取消</button><button className="admin-accounts-primary">生成邀请</button></footer></form> : <div className="admin-invite-result"><label>邀请链接<div className="admin-invite-link"><a href={invitation.path} target="_blank" rel="noreferrer">{new URL(invitation.path, window.location.origin).toString()}</a><button type="button" onClick={() => void copyInvitation()}>复制</button></div></label><label>邀请码<code>{invitation.code}</code></label><p>邀请码只显示这一次。成员打开链接后仍需手动输入邀请码，有效期至 {new Date(invitation.expiresAt).toLocaleString("zh-CN")}。</p></div>}</Dialog>}
      {dialog && typeof dialog === "object" && dialog.type === "subscription" && <Dialog title={`${dialog.account.username} 的 AI 套餐`} onClose={closeDialog}><form onSubmit={saveSubscription}><label>套餐<select name="plan" defaultValue={dialog.account.subscription?.plan ?? "plus"}><option value="plus">Plus</option><option value="pro">Pro</option><option value="max">Max（无限额）</option></select></label><label>时长<select name="cardType" defaultValue="month"><option value="week">周卡</option><option value="month">月卡</option><option value="quarter">季度卡</option><option value="year">年卡</option></select></label><p className="admin-invite-hint">同套餐会从当前到期日续期；更换套餐从现在重新计算。只有后台管理员可以发放。</p><footer>{dialog.account.subscription && <button type="button" className="admin-danger-button" onClick={() => void revokeSubscription(dialog.account)}>取消套餐</button>}<button type="button" onClick={closeDialog}>关闭</button><button className="admin-accounts-primary">确认发放</button></footer></form></Dialog>}
    </Page>
  );
}

type AuditEvent = { id: string; actorLabel: string; actionLabel: string; targetTypeLabel: string; outcome: string; outcomeLabel: string; risk: string; riskLabel: string; createdAt: string };
type AuditResponse = { events: AuditEvent[]; page: number; pageSize: number; total: number; totalPages: number };

function Audit() {
  const [result, setResult] = useState<AuditResponse>({ events: [], page: 1, pageSize: 20, total: 0, totalPages: 1 });
  const [page, setPage] = useState(1);
  const [message, setMessage] = useState("");
  const load = useCallback(() => api<AuditResponse>(`/api/admin/audit?page=${page}&pageSize=20`).then(setResult), [page]);
  useEffect(() => { void load(); }, [load]);
  async function download() {
    setMessage("");
    try {
      const response = await fetch("/api/admin/audit?format=csv", { credentials: "same-origin", cache: "no-store" });
      if (!response.ok) throw new Error("下载失败");
      const url = URL.createObjectURL(await response.blob());
      const link = document.createElement("a");
      link.href = url;
      link.download = `Daylink-安全审计-${new Date().toISOString().slice(0, 10)}.csv`;
      document.body.append(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1_000);
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "下载失败"); }
  }
  const action = <div className="admin-audit-header-actions"><button className="admin-audit-refresh" onClick={() => void load()}>刷新</button><button className="admin-accounts-primary" onClick={() => void download()}>下载日志</button></div>;
  return <Page kicker="安全审计" title="安全事件" subtitle="不记录密码、API Key、提示词或用户内容" action={action}>{message && <p className="admin-accounts-notice">{message}</p>}<section className="admin-audit-list">{result.events.length === 0 && <EmptyState title="暂无安全事件" detail="后台的登录和配置操作会显示在这里。" />}{result.events.map((event) => <article className="admin-audit-row" key={event.id}><div className="admin-audit-row-copy"><h2>{event.actionLabel}</h2><p>{event.actorLabel} · {event.targetTypeLabel} · {new Date(event.createdAt).toLocaleString("zh-CN")}</p></div><span className={`admin-audit-outcome ${event.outcome}`}>{event.outcomeLabel}</span><span className={`admin-audit-risk ${event.risk}`}>{event.riskLabel}</span></article>)}</section><nav className="admin-audit-pagination" aria-label="安全审计分页"><p>共 {result.total} 条 · 第 {result.page} / {result.totalPages} 页</p><div><button disabled={result.page <= 1} onClick={() => setPage((current) => Math.max(1, current - 1))}>上一页</button><button disabled={result.page >= result.totalPages} onClick={() => setPage((current) => Math.min(result.totalPages, current + 1))}>下一页</button></div></nav></Page>;
}

type Provider = { id: string; baseUrl: string; textModel: string; imageModel: string | null; apiKeyHint: string };
type GeneratedAsset = { id: string; url: string; createdAt: string };
type PlanLimit = { plan: "plus" | "pro"; weeklyUnits: number; monthlyUnits: number; updatedAt: string };

function Settings() {
  const [dialog, setDialog] = useState<"password" | "totp" | null>(null);
  const [message, setMessage] = useState("");
  const [enrollment, setEnrollment] = useState<{ secret: string; uri: string } | null>(null);
  const [qr, setQR] = useState("");
  const [ai, setAI] = useState<Provider | null>(null);
  const [testAsset, setTestAsset] = useState<GeneratedAsset | null>(null);
  const [plans, setPlans] = useState<PlanLimit[]>([]);

  const loadAI = useCallback(async () => {
    const result = await api<{ setting: Provider | null }>("/api/admin/ai-settings");
    setAI(result.setting);
  }, []);
  const loadPlans = useCallback(async () => {
    const result = await api<{ plans: PlanLimit[] }>("/api/admin/ai-plans");
    setPlans(result.plans);
  }, []);
  useEffect(() => { void loadAI(); void loadPlans(); }, [loadAI, loadPlans]);

  async function saveAI(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    try {
      const result = await api<{ setting: Provider }>("/api/admin/ai-settings", { method: "POST", body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))) });
      setAI(result.setting);
      event.currentTarget.reset();
      setMessage("AI 服务已加密保存并自动识别模型");
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "AI 配置保存失败"); }
  }

  async function testAI() {
    if (!ai) return;
    try {
      await api("/api/admin/ai-test", { method: "POST", body: JSON.stringify({ providerId: ai.id }) });
      setMessage("API 连接正常");
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "连接失败"); }
  }

  async function testImage() {
    if (!ai) return;
    try {
      const result = await api<{ asset: GeneratedAsset }>("/api/admin/images", { method: "POST", body: JSON.stringify({ providerId: ai.id, prompt: "A minimal blue paper airplane icon on a white background", size: "1024x1024", quality: "low" }) });
      setTestAsset({ ...result.asset, createdAt: new Date().toISOString() });
      setMessage("生图调用正常");
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "生图测试失败"); }
  }

  async function savePlans(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    try {
      const result = await api<{ plans: PlanLimit[] }>("/api/admin/ai-plans", {
        method: "POST",
        body: JSON.stringify({
          plus: { weeklyUnits: Number(form.get("plusWeekly")), monthlyUnits: Number(form.get("plusMonthly")) },
          pro: { weeklyUnits: Number(form.get("proWeekly")), monthlyUnits: Number(form.get("proMonthly")) },
        }),
      });
      setPlans(result.plans);
      setMessage("Plus / Pro 周额度与月额度已保存");
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "套餐额度保存失败"); }
  }

  async function password(event: FormEvent<HTMLFormElement>) { event.preventDefault(); try { await api("/api/admin/security/password", { method: "POST", body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))) }); window.location.replace("/admin"); } catch (reason) { setMessage(reason instanceof Error ? reason.message : "修改失败"); } }
  async function totp(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const form = Object.fromEntries(new FormData(event.currentTarget)); try { if (!enrollment) { const result = await api<{ secret: string; uri: string }>("/api/admin/security/totp", { method: "POST", body: JSON.stringify({ action: "start", currentPassword: form.currentPassword, currentCode: form.currentCode }) }); setEnrollment(result); setQR(await QRCode.toDataURL(result.uri, { width: 360, margin: 0 })); } else { await api("/api/admin/security/totp", { method: "POST", body: JSON.stringify({ action: "verify", code: form.code }) }); window.location.replace("/admin"); } } catch (reason) { setMessage(reason instanceof Error ? reason.message : "操作失败"); } }
  async function closeTotp() {
    if (enrollment) {
      try { await api("/api/admin/security/totp", { method: "DELETE" }); } catch { /* Expired rebinds are harmless. */ }
    }
    setEnrollment(null); setQR(""); setDialog(null);
  }

  return (
    <Page kicker="设置" title="后台设置" subtitle="AI 接口与后台登录安全">
      {message && <p className="admin-accounts-notice">{message}</p>}
      <section className="admin-settings-card admin-settings-ai">
        <header><div><h2>AI 服务</h2><p>兼容 Codex Responses API 的第三方中转</p></div>{ai && <span className="admin-accounts-status active">已配置</span>}</header>
        <form onSubmit={saveAI}>
          <label>API 地址<input name="baseUrl" type="url" required defaultValue={ai?.baseUrl ?? ""} placeholder="https://api.example.com" /></label>
          <label>API Key<input name="apiKey" type="password" required={!ai} autoComplete="off" placeholder={ai ? `已保存 · ${ai.apiKeyHint}（留空不修改）` : "输入 API Key"} /></label>
          {ai && <p className="admin-settings-models">已自动选择 {ai.textModel}{ai.imageModel ? ` · ${ai.imageModel}` : ""}</p>}
          <div className="admin-settings-ai-actions"><button className="admin-accounts-primary">加密保存</button>{ai && <><button type="button" onClick={() => void testAI()}>测试 API</button><button type="button" onClick={() => void testImage()}>测试生图</button></>}</div>
        </form>
        {testAsset && <a className="admin-settings-test-image" href={testAsset.url} target="_blank" rel="noreferrer"><img src={testAsset.url} alt="AI 生图测试结果" /><span>生图测试结果</span></a>}
      </section>
      <section className="admin-settings-card admin-settings-ai admin-settings-plans">
        <header><div><h2>AI 套餐额度</h2><p>本地 AI 与 SSH Agent 共用账号额度；生图按 5 单位、对话按 1 单位计费</p></div><span className="admin-plan-badge max">Max 无限额</span></header>
        <form key={plans.map((item) => `${item.plan}:${item.weeklyUnits}:${item.monthlyUnits}`).join("|")} onSubmit={savePlans}>
          <div className="admin-plan-limit-grid">
            <strong>Plus</strong><label>每周单位<input name="plusWeekly" type="number" min="1" max="10000000" required defaultValue={plans.find((item) => item.plan === "plus")?.weeklyUnits || ""} /></label><label>每月单位<input name="plusMonthly" type="number" min="1" max="10000000" required defaultValue={plans.find((item) => item.plan === "plus")?.monthlyUnits || ""} /></label>
            <strong>Pro</strong><label>每周单位<input name="proWeekly" type="number" min="1" max="10000000" required defaultValue={plans.find((item) => item.plan === "pro")?.weeklyUnits || ""} /></label><label>每月单位<input name="proMonthly" type="number" min="1" max="10000000" required defaultValue={plans.find((item) => item.plan === "pro")?.monthlyUnits || ""} /></label>
          </div>
          <p className="admin-settings-models">月额度不得低于周额度，Pro 不得低于 Plus。自然周按 UTC 周一重置，自然月 1 日重置。</p>
          <div className="admin-settings-ai-actions"><button className="admin-accounts-primary">保存套餐额度</button></div>
        </form>
      </section>
      <section className="admin-settings-card">
        <div className="admin-settings-row"><div className="admin-settings-row-copy"><h3>登录密码</h3><p>修改后撤销全部后台会话</p></div><button onClick={() => { setMessage(""); setDialog("password"); }}>修改密码</button></div>
        <div className="admin-settings-row"><div className="admin-settings-row-copy"><h3>双重验证</h3><p>Microsoft Authenticator</p></div><button onClick={() => { setMessage(""); setEnrollment(null); setDialog("totp"); }}>重新绑定</button></div>
      </section>
      {dialog === "password" && <Dialog title="修改登录密码" onClose={() => setDialog(null)}><form onSubmit={password}><label>当前密码<input name="currentPassword" type="password" required /></label><label>当前动态验证码<input name="currentCode" inputMode="numeric" pattern="[0-9]{6}" required /></label><label>新密码<input name="newPassword" type="password" minLength={12} required /></label><label>确认新密码<input name="confirmPassword" type="password" minLength={12} required /></label>{message && <p className="admin-accounts-dialog-error">{message}</p>}<footer><button type="button" onClick={() => setDialog(null)}>取消</button><button className="admin-accounts-primary">确认修改</button></footer></form></Dialog>}
      {dialog === "totp" && <Dialog title="重新绑定双重验证" onClose={() => void closeTotp()}><form onSubmit={totp}>{!enrollment ? <><label>当前密码<input name="currentPassword" type="password" required /></label><label>当前动态验证码<input name="currentCode" inputMode="numeric" pattern="[0-9]{6}" required /></label></> : <><div className="admin-settings-qr"><img src={qr} width="176" height="176" alt="新的双重验证二维码" /></div><div className="admin-auth-secret"><code>{enrollment.secret}</code></div><label>新动态验证码<input name="code" inputMode="numeric" pattern="[0-9]{6}" required /></label></>}{message && <p className="admin-accounts-dialog-error">{message}</p>}<footer><button type="button" onClick={() => void closeTotp()}>取消</button><button className="admin-accounts-primary">{enrollment ? "验证并绑定" : "继续"}</button></footer></form></Dialog>}
    </Page>
  );
}

function planName(plan: Subscription["plan"]) {
  return plan === "plus" ? "Plus" : plan === "pro" ? "Pro" : "Max";
}

function Dialog({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) {
  return <div className="admin-accounts-dialog-backdrop"><section className="admin-accounts-dialog" role="dialog" aria-modal="true"><header><h2>{title}</h2><button type="button" onClick={onClose} aria-label="关闭">×</button></header>{children}</section></div>;
}

function EmptyState({ title, detail }: { title: string; detail: string }) {
  return <div className="admin-empty"><h2>{title}</h2><p>{detail}</p></div>;
}
