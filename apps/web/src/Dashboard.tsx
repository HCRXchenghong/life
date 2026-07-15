import QRCode from "qrcode";
import { FormEvent, ReactNode, useCallback, useEffect, useState } from "react";
import { api, navigate } from "./api";

type Props = { username: string; path: string; onLogout: () => void };

export function Dashboard({ username, path, onLogout }: Props) {
  const active = section(path);
  async function logout() {
    await api("/api/auth/logout", { method: "POST" });
    onLogout();
  }
  return (
    <main className="admin-overview-shell">
      <aside className="admin-overview-sidebar">
        <div className="admin-overview-sidebar-head">
          <NavLink href="/admin" className="admin-overview-brand"><span className="admin-auth-brand-mark" /><span>Daylink</span></NavLink>
          <span className="admin-overview-product">管理后台</span>
        </div>
        <nav className="admin-overview-nav" aria-label="后台导航">
          <NavLink href="/admin" active={active === "overview"}>概览</NavLink>
          <NavLink href="/admin/accounts" active={active === "accounts"}>App 账号</NavLink>
          <NavLink href="/admin/ai" active={active === "ai"}>AI 配置</NavLink>
          <NavLink href="/admin/audit" active={active === "audit"}>安全审计</NavLink>
          <NavLink href="/admin/settings" active={active === "settings"}>设置</NavLink>
        </nav>
        <div className="admin-overview-account"><span className="admin-overview-avatar">{username.slice(0, 1).toUpperCase()}</span><strong>{username}</strong><button onClick={() => void logout()}>退出</button></div>
      </aside>
      {active === "overview" && <Overview />}
      {active === "accounts" && <Accounts />}
      {active === "ai" && <Providers />}
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
  if (path.includes("/ai")) return "ai";
  if (path.includes("/audit")) return "audit";
  if (path.includes("/settings")) return "settings";
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
      <p className="admin-overview-privacy"><span className="admin-overview-lock" />管理员无法读取用户的端到端加密内容</p>
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
  return <Page kicker="概览" title="开始使用 Daylink" subtitle="账号、AI 服务和部署服务器运行状态"><div className="admin-overview-setup"><Action title="App 账号" detail={`已创建 ${data?.appAccountCount ?? 0} 个账号`} href="/admin/accounts" /><Action title="AI 服务" detail={`已配置 ${data?.aiProviderCount ?? 0} 个服务`} href="/admin/ai" /></div><section className="admin-server-section"><header><div><h2>服务器状态</h2><p>每 30 秒自动更新 · 支持 Windows、macOS 和 Ubuntu</p></div><button className="admin-audit-refresh" onClick={() => void load()}>刷新数据</button></header><div className="admin-server-list">{data?.servers.map((server) => <ServerCard server={server} key={server.id} />) ?? <div className="admin-server-loading">正在读取服务器状态…</div>}</div><p className="admin-server-privacy">这里只显示 Daylink 后台部署服务器，不读取 App 用户保存的主机信息。</p></section></Page>;
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
  return <article className="admin-server-card"><header><div><h3>{server.name}</h3><p>{server.hostname} · {server.systemLabel} · {server.architecture}</p></div><span className="admin-server-online">运行中</span></header><div className="admin-server-metrics">{metrics.map((metric) => <div className="admin-server-metric" key={metric.label}><div><span>{metric.label}</span><strong>{metric.percent.toFixed(1)}%</strong></div><div className="admin-server-track"><span style={{ width: `${Math.min(100, Math.max(0, metric.percent))}%` }} /></div><p>{metric.detail}</p></div>)}</div><footer>更新于 {new Date(server.updatedAt).toLocaleString("zh-CN")}</footer></article>;
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

type Account = { id: string; username: string; status: string; passwordChangeRequired: boolean; lockedUntil: string | null; lastLoginAt: string | null; createdAt: string };

function Accounts() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [dialog, setDialog] = useState<Account | "create" | null>(null);
  const [message, setMessage] = useState("");
  const load = useCallback(() => api<{ accounts: Account[] }>("/api/admin/app-accounts").then((value) => setAccounts(value.accounts)), []);
  useEffect(() => { void load(); }, [load]);
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.currentTarget));
    try {
      await api("/api/admin/app-accounts", { method: dialog === "create" ? "POST" : "PATCH", body: JSON.stringify(dialog === "create" ? values : { ...values, id: dialog?.id, action: "reset_password" }) });
      setDialog(null); setMessage("账号已保存"); await load();
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "保存失败"); }
  }
  async function toggle(account: Account) {
    await api("/api/admin/app-accounts", { method: "PATCH", body: JSON.stringify({ id: account.id, action: account.status === "active" ? "disable" : "enable" }) });
    await load();
  }
  return <Page kicker="App 账号" title="成员账号" subtitle="只管理登录状态，不提供用户内容读取接口" action={<button className="admin-accounts-primary" onClick={() => setDialog("create")}>创建账号</button>}>{message && <p className="admin-accounts-notice">{message}</p>}<section className="admin-accounts-list">{accounts.length === 0 && <EmptyState title="还没有 App 账号" detail="创建账号后，成员即可登录并在不同设备间同步数据。" />}{accounts.map((account) => <article className="admin-accounts-row" key={account.id}><span className="admin-accounts-row-avatar">{account.username[0].toUpperCase()}</span><div className="admin-accounts-row-copy"><h2>{account.username}</h2><p>{account.passwordChangeRequired ? "等待修改初始密码" : account.lastLoginAt ? `最近登录 ${new Date(account.lastLoginAt).toLocaleString()}` : "尚未登录"}</p></div><span className={`admin-accounts-status ${account.status}`}>{account.status === "active" ? "正常" : "已停用"}</span><div className="admin-accounts-actions"><button onClick={() => setDialog(account)}>重置密码</button><button onClick={() => void toggle(account)}>{account.status === "active" ? "停用" : "启用"}</button></div></article>)}</section>{dialog && <Dialog title={dialog === "create" ? "创建 App 账号" : `重置 ${dialog.username} 的密码`} onClose={() => setDialog(null)}><form onSubmit={save}>{dialog === "create" && <label>App 账号<input name="username" minLength={4} maxLength={32} required autoFocus /></label>}<label>密码<input name="password" type="password" minLength={12} maxLength={128} required /></label><label>确认密码<input name="confirmPassword" type="password" minLength={12} maxLength={128} required /></label><footer><button type="button" onClick={() => setDialog(null)}>取消</button><button className="admin-accounts-primary">保存</button></footer></form></Dialog>}</Page>;
}

type Provider = { id: string; name: string; kind: string; baseUrl: string; textModel: string; imageModel: string | null; apiKeyHint: string; enabled: boolean; updatedAt: string };
type GeneratedAsset = { id: string; providerConfigId: string; contentType: string; byteSize: number; width: number | null; height: number | null; createdAt: string; url: string };

function Providers() {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [assets, setAssets] = useState<GeneratedAsset[]>([]);
  const [editing, setEditing] = useState<Provider | "create" | null>(null);
  const [message, setMessage] = useState("");
  const load = useCallback(async () => {
    const [providerResult, assetResult] = await Promise.all([
      api<{ providers: Provider[] }>("/api/admin/providers"),
      api<{ assets: GeneratedAsset[] }>("/api/admin/images"),
    ]);
    setProviders(providerResult.providers);
    setAssets(assetResult.assets);
  }, []);
  useEffect(() => { void load(); }, [load]);
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const body = { ...(editing === "create" ? {} : { id: editing?.id }), name: form.get("name"), kind: form.get("kind"), baseUrl: form.get("baseUrl"), textModel: form.get("textModel"), imageModel: form.get("imageModel"), apiKey: form.get("apiKey"), enabled: form.get("enabled") === "on" };
    try { await api("/api/admin/providers", { method: "POST", body: JSON.stringify(body) }); setEditing(null); setMessage("AI 服务已加密保存"); await load(); } catch (reason) { setMessage(reason instanceof Error ? reason.message : "保存失败"); }
  }
  async function test(provider: Provider) { try { await api("/api/admin/ai-test", { method: "POST", body: JSON.stringify({ providerId: provider.id }) }); setMessage(`${provider.name} 连接正常`); } catch (reason) { setMessage(reason instanceof Error ? reason.message : "连接失败"); } }
  async function generate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    try {
      await api("/api/admin/images", { method: "POST", body: JSON.stringify(Object.fromEntries(form)) });
      setMessage("图片已生成并加密记录元数据");
      await load();
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "生图失败"); }
  }
  const imageProviders = providers.filter((provider) => provider.enabled && provider.imageModel);
  return <Page kicker="AI 配置" title="AI 服务" subtitle="管理第三方 API、对话模型与生图模型" action={<button className="admin-accounts-primary" onClick={() => setEditing("create")}>添加服务</button>}>{message && <p className="admin-accounts-notice">{message}</p>}<section className="admin-ai-list">{providers.length === 0 && <EmptyState title="还没有 AI 服务" detail="添加兼容 Responses API 的第三方服务后即可使用。" />}{providers.map((provider) => <article className="admin-ai-row" key={provider.id}><div className="admin-ai-row-copy"><h2>{provider.name}</h2><p>{provider.textModel}{provider.imageModel ? ` · ${provider.imageModel}` : ""}</p><small>{provider.baseUrl} · Key {provider.apiKeyHint}</small></div><span className={`admin-accounts-status ${provider.enabled ? "active" : "disabled"}`}>{provider.enabled ? "已启用" : "已停用"}</span><div className="admin-accounts-actions"><button onClick={() => void test(provider)}>测试连接</button><button onClick={() => setEditing(provider)}>编辑</button></div></article>)}</section><section className="admin-ai-generator"><header><h2>生成图片</h2><p>使用已启用且配置了生图模型的第三方服务</p></header><form onSubmit={generate}><select name="providerId" required defaultValue=""><option value="" disabled>选择服务</option>{imageProviders.map((provider) => <option key={provider.id} value={provider.id}>{provider.name} · {provider.imageModel}</option>)}</select><textarea name="prompt" required minLength={1} maxLength={8000} placeholder="描述要生成的图片" /><div><select name="size" defaultValue="1024x1024"><option value="1024x1024">正方形</option><option value="1536x1024">横向</option><option value="1024x1536">纵向</option></select><select name="quality" defaultValue="medium"><option value="low">快速</option><option value="medium">标准</option><option value="high">高质量</option></select><button className="admin-accounts-primary" disabled={imageProviders.length === 0}>生成</button></div></form>{assets.length > 0 && <div className="admin-ai-assets">{assets.map((asset) => <a href={asset.url} target="_blank" rel="noreferrer" key={asset.id}><img src={asset.url} alt="后台生成的图片" loading="lazy" /><span>{new Date(asset.createdAt).toLocaleString()}</span></a>)}</div>}</section>{editing && <Dialog title={editing === "create" ? "添加 AI 服务" : "编辑 AI 服务"} onClose={() => setEditing(null)}><form onSubmit={save}><label>名称<input name="name" required maxLength={80} defaultValue={editing === "create" ? "" : editing.name} /></label><label>协议<select name="kind" defaultValue={editing === "create" ? "openai_compatible" : editing.kind}><option value="openai_compatible">第三方 Responses</option><option value="openai_responses">Codex Responses 兼容</option></select></label><label>API 地址<input name="baseUrl" type="url" required defaultValue={editing === "create" ? "" : editing.baseUrl} placeholder="https://api.example.com/v1" /></label><label>对话模型<input name="textModel" required defaultValue={editing === "create" ? "" : editing.textModel} /></label><label>生图模型<input name="imageModel" defaultValue={editing === "create" ? "" : editing.imageModel ?? ""} /></label><label>API Key<input name="apiKey" type="password" required={editing === "create"} /></label><label className="admin-ai-enabled"><input name="enabled" type="checkbox" defaultChecked={editing === "create" || editing.enabled} />启用</label><footer><button type="button" onClick={() => setEditing(null)}>取消</button><button className="admin-accounts-primary">加密保存</button></footer></form></Dialog>}</Page>;
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

function Settings() {
  const [dialog, setDialog] = useState<"password" | "totp" | null>(null);
  const [message, setMessage] = useState("");
  const [enrollment, setEnrollment] = useState<{ secret: string; uri: string } | null>(null);
  const [qr, setQR] = useState("");
  async function password(event: FormEvent<HTMLFormElement>) { event.preventDefault(); try { await api("/api/admin/security/password", { method: "POST", body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))) }); window.location.replace("/admin"); } catch (reason) { setMessage(reason instanceof Error ? reason.message : "修改失败"); } }
  async function totp(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const form = Object.fromEntries(new FormData(event.currentTarget)); try { if (!enrollment) { const result = await api<{ secret: string; uri: string }>("/api/admin/security/totp", { method: "POST", body: JSON.stringify({ action: "start", currentPassword: form.currentPassword, currentCode: form.currentCode }) }); setEnrollment(result); setQR(await QRCode.toDataURL(result.uri, { width: 360, margin: 0 })); } else { await api("/api/admin/security/totp", { method: "POST", body: JSON.stringify({ action: "verify", code: form.code }) }); window.location.replace("/admin"); } } catch (reason) { setMessage(reason instanceof Error ? reason.message : "操作失败"); } }
  async function closeTotp() {
    if (enrollment) {
      try { await api("/api/admin/security/totp", { method: "DELETE" }); } catch { /* Expired rebinds are harmless. */ }
    }
    setEnrollment(null); setQR(""); setDialog(null);
  }
  return <Page kicker="设置" title="后台设置" subtitle="敏感修改需要当前密码和不可重放的 TOTP"><section className="admin-settings-card"><div className="admin-settings-row"><div className="admin-settings-row-copy"><h3>登录密码</h3><p>修改后撤销全部后台会话</p></div><button onClick={() => { setMessage(""); setDialog("password"); }}>修改密码</button></div><div className="admin-settings-row"><div className="admin-settings-row-copy"><h3>双重验证</h3><p>Microsoft Authenticator</p></div><button onClick={() => { setMessage(""); setEnrollment(null); setDialog("totp"); }}>重新绑定</button></div></section>{dialog === "password" && <Dialog title="修改登录密码" onClose={() => setDialog(null)}><form onSubmit={password}><label>当前密码<input name="currentPassword" type="password" required /></label><label>当前动态验证码<input name="currentCode" inputMode="numeric" pattern="[0-9]{6}" required /></label><label>新密码<input name="newPassword" type="password" minLength={12} required /></label><label>确认新密码<input name="confirmPassword" type="password" minLength={12} required /></label>{message && <p className="admin-accounts-dialog-error">{message}</p>}<footer><button type="button" onClick={() => setDialog(null)}>取消</button><button className="admin-accounts-primary">确认修改</button></footer></form></Dialog>}{dialog === "totp" && <Dialog title="重新绑定双重验证" onClose={() => void closeTotp()}><form onSubmit={totp}>{!enrollment ? <><label>当前密码<input name="currentPassword" type="password" required /></label><label>当前动态验证码<input name="currentCode" inputMode="numeric" pattern="[0-9]{6}" required /></label></> : <><div className="admin-settings-qr"><img src={qr} width="176" height="176" alt="新的双重验证二维码" /></div><div className="admin-auth-secret"><code>{enrollment.secret}</code></div><label>新动态验证码<input name="code" inputMode="numeric" pattern="[0-9]{6}" required /></label></>}{message && <p className="admin-accounts-dialog-error">{message}</p>}<footer><button type="button" onClick={() => void closeTotp()}>取消</button><button className="admin-accounts-primary">{enrollment ? "验证并绑定" : "继续"}</button></footer></form></Dialog>}</Page>;
}

function Dialog({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) {
  return <div className="admin-accounts-dialog-backdrop"><section className="admin-accounts-dialog" role="dialog" aria-modal="true"><header><h2>{title}</h2><button type="button" onClick={onClose} aria-label="关闭">×</button></header>{children}</section></div>;
}

function EmptyState({ title, detail }: { title: string; detail: string }) {
  return <div className="admin-empty"><h2>{title}</h2><p>{detail}</p></div>;
}
