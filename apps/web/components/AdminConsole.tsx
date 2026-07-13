"use client";
/* eslint-disable @next/next/no-img-element -- protected identity-aware asset URLs cannot be fetched by the optimizer */

import Link from "next/link";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

type Provider = {
  id: string;
  name: string;
  kind: string;
  baseUrl: string;
  textModel: string;
  imageModel: string | null;
  apiKeyHint: string;
  enabled: boolean;
};

type Asset = { id: string; url: string; byteSize: number; createdAt: string };
type MobileToken = {
  id: string;
  name: string;
  tokenHint: string;
  expiresAt: string | null;
  lastUsedAt: string | null;
  revokedAt: string | null;
  createdAt: string;
};

export function AdminConsole({ user }: { user: { displayName: string; email: string } }) {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [assets, setAssets] = useState<Asset[]>([]);
  const [mobileTokens, setMobileTokens] = useState<MobileToken[]>([]);
  const [issuedToken, setIssuedToken] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const [providerResponse, assetResponse, tokenResponse] = await Promise.all([
      fetch("/api/admin/providers", { cache: "no-store" }),
      fetch("/api/admin/images", { cache: "no-store" }),
      fetch("/api/admin/mobile-tokens", { cache: "no-store" }),
    ]);
    if (providerResponse.ok) {
      const payload = (await providerResponse.json()) as { providers: Provider[] };
      setProviders(payload.providers);
    }
    if (assetResponse.ok) {
      const payload = (await assetResponse.json()) as { assets: Asset[] };
      setAssets(payload.assets);
    }
    if (tokenResponse.ok) {
      const payload = (await tokenResponse.json()) as { tokens: MobileToken[] };
      setMobileTokens(payload.tokens);
    }
  }, []);

  useEffect(() => {
    let active = true;
    Promise.all([
      fetch("/api/admin/providers", { cache: "no-store" }),
      fetch("/api/admin/images", { cache: "no-store" }),
      fetch("/api/admin/mobile-tokens", { cache: "no-store" }),
    ]).then(async ([providerResponse, assetResponse, tokenResponse]) => {
      if (!active) return;
      if (providerResponse.ok) {
        const payload = (await providerResponse.json()) as { providers: Provider[] };
        setProviders(payload.providers);
      }
      if (assetResponse.ok) {
        const payload = (await assetResponse.json()) as { assets: Asset[] };
        setAssets(payload.assets);
      }
      if (tokenResponse.ok) {
        const payload = (await tokenResponse.json()) as { tokens: MobileToken[] };
        setMobileTokens(payload.tokens);
      }
    }).catch(() => undefined);
    return () => { active = false; };
  }, []);

  async function createProvider(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy("provider"); setNotice("");
    const form = new FormData(event.currentTarget);
    const response = await fetch("/api/admin/providers", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(Object.fromEntries(form)),
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    if (!response.ok) return setNotice(result.error?.message ?? "保存失败");
    event.currentTarget.reset();
    setNotice("AI Provider 已加密保存。浏览器不会再次收到完整 Key。");
    await refresh();
  }

  async function testProvider(providerId: string) {
    setBusy(`test:${providerId}`); setNotice("");
    const response = await fetch("/api/admin/ai-test", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ providerId }),
    });
    const result = (await response.json()) as {
      output?: string;
      error?: { message?: string };
    };
    setBusy(null);
    setNotice(response.ok ? `连接成功：${result.output ?? "OK"}` : result.error?.message ?? "连接失败");
  }

  async function generateImage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy("image"); setNotice("");
    const body = Object.fromEntries(new FormData(event.currentTarget));
    const response = await fetch("/api/admin/images", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    if (!response.ok) return setNotice(result.error?.message ?? "生图失败");
    setNotice("图片已生成并写入受保护的对象存储。");
    await refresh();
  }

  async function issueMobileToken(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy("mobile-token"); setNotice(""); setIssuedToken("");
    const form = new FormData(event.currentTarget);
    const expiresAtValue = String(form.get("expiresAt") ?? "");
    const response = await fetch("/api/admin/mobile-tokens", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        name: form.get("name"),
        expiresAt: expiresAtValue ? new Date(`${expiresAtValue}T23:59:59`).toISOString() : null,
      }),
    });
    const result = (await response.json()) as { plaintext?: string; error?: { message?: string } };
    setBusy(null);
    if (!response.ok) return setNotice(result.error?.message ?? "签发失败");
    setIssuedToken(result.plaintext ?? "");
    event.currentTarget.reset();
    setNotice("移动 API Token 已签发；明文只显示这一次，请立即保存到 App 安全存储。");
    await refresh();
  }

  async function revokeMobileToken(id: string) {
    setBusy(`revoke:${id}`); setNotice("");
    const response = await fetch(`/api/admin/mobile-tokens?id=${encodeURIComponent(id)}`, {
      method: "DELETE",
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    setNotice(response.ok ? "移动 API Token 已撤销。" : result.error?.message ?? "撤销失败");
    if (response.ok) await refresh();
  }

  const imageProviders = useMemo(() => providers.filter((item) => item.enabled && item.imageModel), [providers]);

  return (
    <main className="shell admin-shell">
      <nav className="topbar">
        <Link className="brand" href="/"><span className="brand-mark">D</span>Daylink</Link>
        <div className="account"><span className="avatar">{user.displayName.slice(0, 1).toUpperCase()}</span><div><strong>{user.displayName}</strong><small>{user.email}</small></div></div>
      </nav>

      <header className="admin-header">
        <div><p className="eyebrow">CONTROL PLANE</p><h1>后台工作台</h1><p>管理 AI 接口、生成资产、分享活动和安全审计。</p></div>
        <span className="secure-badge">密钥已封装</span>
      </header>

      {notice && <div className="notice" role="status">{notice}</div>}

      <div className="admin-grid">
        <section className="admin-card span-two">
          <div className="section-heading"><div><span className="section-index">01</span><h2>AI Provider</h2></div><p>支持自定义 HTTPS Endpoint、模型和 API Key</p></div>
          <form className="form-grid" onSubmit={createProvider}>
            <label>显示名称<input name="name" required placeholder="OpenAI Production" /></label>
            <label>接口类型<select name="kind" defaultValue="openai_responses"><option value="openai_responses">OpenAI Responses</option><option value="openai_compatible">OpenAI Compatible</option><option value="anthropic_compatible">Anthropic Compatible</option></select></label>
            <label className="wide">Base URL<input name="baseUrl" type="url" required defaultValue="https://api.openai.com/v1" /></label>
            <label>文本模型<input name="textModel" required defaultValue="gpt-5.6" /></label>
            <label>生图模型<input name="imageModel" defaultValue="gpt-image-2" /></label>
            <label className="wide">API Key<input name="apiKey" type="password" autoComplete="new-password" required placeholder="仅在提交时发送" /></label>
            <div className="wide form-foot"><p>Key 使用 AES-GCM 封装；列表和日志只显示末四位提示。</p><button className="button" disabled={busy === "provider"}>{busy === "provider" ? "保存中…" : "加密保存"}</button></div>
          </form>
          <div className="provider-list">
            {providers.length === 0 ? <p className="empty">尚未配置 Provider</p> : providers.map((provider) => (
              <article key={provider.id} className="provider-row"><div><strong>{provider.name}</strong><span>{provider.kind} · {provider.textModel} · {provider.apiKeyHint}</span></div><button className="button button-small button-ghost" onClick={() => testProvider(provider.id)} disabled={busy === `test:${provider.id}`}>测试连接</button></article>
            ))}
          </div>
        </section>

        <section className="admin-card span-two">
          <div className="section-heading"><div><span className="section-index">02</span><h2>移动端访问令牌</h2></div><p>每台设备独立签发、仅存 SHA-256 哈希、可随时撤销</p></div>
          <form className="form-grid" onSubmit={issueMobileToken}>
            <label>设备名称<input name="name" required placeholder="我的 iPhone" /></label>
            <label>过期日期（可选）<input name="expiresAt" type="date" /></label>
            <div className="wide form-foot"><p>令牌只允许访问你自己的 Provider；服务端永不保存可恢复明文。</p><button className="button" disabled={busy === "mobile-token"}>{busy === "mobile-token" ? "签发中…" : "签发令牌"}</button></div>
          </form>
          {issuedToken && <div className="notice"><strong>仅显示一次：</strong><code>{issuedToken}</code></div>}
          <div className="provider-list">
            {mobileTokens.length === 0 ? <p className="empty">尚未签发移动令牌</p> : mobileTokens.map((token) => (
              <article key={token.id} className="provider-row"><div><strong>{token.name}</strong><span>{token.tokenHint} · {token.revokedAt ? "已撤销" : token.expiresAt ? `有效至 ${new Date(token.expiresAt).toLocaleDateString("zh-CN")}` : "长期有效"}{token.lastUsedAt ? ` · 最近使用 ${new Date(token.lastUsedAt).toLocaleString("zh-CN")}` : ""}</span></div>{!token.revokedAt && <button className="button button-small button-ghost" onClick={() => revokeMobileToken(token.id)} disabled={busy === `revoke:${token.id}`}>撤销</button>}</article>
            ))}
          </div>
        </section>

        <section className="admin-card">
          <div className="section-heading"><div><span className="section-index">03</span><h2>AI 生图</h2></div></div>
          <form className="stack-form" onSubmit={generateImage}>
            <label>Provider<select name="providerId" required>{imageProviders.map((provider) => <option key={provider.id} value={provider.id}>{provider.name} · {provider.imageModel}</option>)}</select></label>
            <label>提示词<textarea name="prompt" required rows={5} placeholder="描述要生成的完整画面…" /></label>
            <div className="split-fields"><label>尺寸<select name="size" defaultValue="1024x1024"><option>1024x1024</option><option>1536x1024</option><option>1024x1536</option><option>2048x1152</option></select></label><label>质量<select name="quality" defaultValue="medium"><option value="low">低</option><option value="medium">中</option><option value="high">高</option></select></label></div>
            <button className="button" disabled={busy === "image" || imageProviders.length === 0}>{busy === "image" ? "生成中…" : "生成并保存"}</button>
          </form>
        </section>

        <PollCreator setNotice={setNotice} />
      </div>

      {assets.length > 0 && <section className="asset-section"><div className="section-heading"><div><span className="section-index">05</span><h2>最近生成</h2></div></div><div className="asset-grid">{assets.map((asset) => <figure key={asset.id}>{/* Protected, identity-aware URL cannot be fetched by the image optimizer. */}<img src={asset.url} alt="AI 生成资产" /><figcaption>{new Date(asset.createdAt).toLocaleString("zh-CN")} · {Math.round(asset.byteSize / 1024)} KB</figcaption></figure>)}</div></section>}
    </main>
  );
}

function PollCreator({ setNotice }: { setNotice: (message: string) => void }) {
  const [busy, setBusy] = useState(false);
  const [inviteUrl, setInviteUrl] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setInviteUrl("");
    const form = new FormData(event.currentTarget);
    const base = new Date(String(form.get("date")));
    const slots = [10, 14, 19].map((hour) => {
      const start = new Date(base); start.setHours(hour, 0, 0, 0);
      const end = new Date(start); end.setHours(hour + 2);
      return { startsAt: start.toISOString(), endsAt: end.toISOString(), label: `${hour}:00` };
    });
    const response = await fetch("/api/polls", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ title: form.get("title"), timezone: Intl.DateTimeFormat().resolvedOptions().timeZone, slots }) });
    const result = (await response.json()) as {
      poll?: { inviteUrl: string };
      error?: { message?: string };
    }; setBusy(false);
    if (!response.ok) return setNotice(result.error?.message ?? "创建失败");
    setInviteUrl(result.poll?.inviteUrl ?? ""); setNotice("选时间链接已创建；管理令牌只在本次响应中返回，请由 App 安全保存。");
  }
  return <section className="admin-card"><div className="section-heading"><div><span className="section-index">04</span><h2>好友选时间</h2></div></div><form className="stack-form" onSubmit={submit}><label>活动名称<input name="title" required placeholder="周末去郊外" /></label><label>候选日期<input name="date" type="date" required /></label><p className="helper">快速创建当天 10:00、14:00、19:00 三个候选时段；App 会提供完整编辑能力。</p><button className="button" disabled={busy}>{busy ? "创建中…" : "生成邀请链接"}</button>{inviteUrl && <a className="result-link" href={inviteUrl}>{inviteUrl}</a>}</form></section>;
}
