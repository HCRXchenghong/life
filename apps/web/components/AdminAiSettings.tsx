"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { AdminCssIcon, AdminShell } from "./AdminShell";

type Provider = {
  id: string;
  name: string;
  kind: "openai_responses" | "openai_compatible" | "anthropic_compatible";
  baseUrl: string;
  textModel: string;
  imageModel: string | null;
  apiKeyHint: string;
  enabled: boolean;
  updatedAt: string;
};

export function AdminAiSettings({
  username,
  providers,
}: {
  username: string;
  providers: Provider[];
}) {
  const router = useRouter();
  const [editing, setEditing] = useState<Provider | "new" | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!editing) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !busy) setEditing(null);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [editing, busy]);

  function openDialog(provider: Provider | "new") {
    setError("");
    setNotice("");
    setEditing(provider);
  }

  async function saveProvider(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!editing) return;
    const form = new FormData(event.currentTarget);
    setBusy("save");
    setError("");
    const response = await fetch("/api/admin/providers", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        ...(editing === "new" ? {} : { id: editing.id }),
        name: form.get("name"),
        kind: form.get("kind"),
        baseUrl: form.get("baseUrl"),
        textModel: form.get("textModel"),
        imageModel: form.get("imageModel"),
        apiKey: form.get("apiKey"),
        enabled: form.get("enabled") === "on",
      }),
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    if (!response.ok) {
      setError(result.error?.message ?? "保存失败，请稍后重试");
      return;
    }
    setNotice(editing === "new" ? "AI 服务已加密保存" : "AI 服务已更新");
    setEditing(null);
    router.refresh();
  }

  async function testProvider(provider: Provider) {
    setBusy(`test:${provider.id}`);
    setError("");
    setNotice("");
    const response = await fetch("/api/admin/ai-test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ providerId: provider.id }),
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    if (!response.ok) {
      setError(result.error?.message ?? "连接测试失败");
      return;
    }
    setNotice(`${provider.name} 连接正常`);
  }

  async function toggleProvider(provider: Provider) {
    const nextEnabled = !provider.enabled;
    setBusy(`toggle:${provider.id}`);
    setError("");
    setNotice("");
    const response = await fetch("/api/admin/providers", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        id: provider.id,
        name: provider.name,
        kind: provider.kind,
        baseUrl: provider.baseUrl,
        textModel: provider.textModel,
        imageModel: provider.imageModel ?? "",
        apiKey: "",
        enabled: nextEnabled,
      }),
    });
    const result = (await response.json()) as { error?: { message?: string } };
    setBusy(null);
    if (!response.ok) {
      setError(result.error?.message ?? "操作失败，请稍后重试");
      return;
    }
    setNotice(nextEnabled ? `${provider.name} 已启用` : `${provider.name} 已停用`);
    router.refresh();
  }

  return (
    <AdminShell username={username} active="ai">
      <section className="admin-overview-main admin-ai-main" aria-labelledby="ai-title">
        <p className="admin-overview-kicker">AI 配置</p>
        <header className="admin-accounts-heading">
          <div>
            <h1 id="ai-title">AI 服务</h1>
            <p className="admin-overview-subtitle">配置第三方 API，供 App 助手、生图与 Codex 兼容调用</p>
          </div>
          <button className="admin-accounts-primary" type="button" onClick={() => openDialog("new")}>
            添加服务
          </button>
        </header>

        {notice && <p className="admin-accounts-notice" role="status">{notice}</p>}
        {error && <p className="admin-accounts-error" role="alert">{error}</p>}

        {providers.length === 0 ? (
          <section className="admin-accounts-empty admin-ai-empty" aria-label="暂无 AI 服务">
            <span className="admin-ai-empty-icon"><AdminCssIcon name="ai" /></span>
            <h2>暂无 AI 服务</h2>
            <p>填写 API 地址、Key 与模型后，即可接入第三方 AI 服务</p>
            <button className="admin-accounts-primary" type="button" onClick={() => openDialog("new")}>
              添加服务
            </button>
          </section>
        ) : (
          <section className="admin-ai-list" aria-label="AI 服务列表">
            {providers.map((provider) => (
              <article className="admin-ai-row" key={provider.id}>
                <span className="admin-ai-row-icon"><AdminCssIcon name="ai" /></span>
                <div className="admin-ai-row-copy">
                  <h2>{provider.name}</h2>
                  <p>{kindLabel(provider.kind)} · {provider.textModel}{provider.imageModel ? ` · ${provider.imageModel}` : ""}</p>
                  <small>{provider.baseUrl} · Key {provider.apiKeyHint}</small>
                </div>
                <span className={`admin-accounts-status ${provider.enabled ? "" : "disabled"}`}>
                  {provider.enabled ? "已启用" : "已停用"}
                </span>
                <div className="admin-accounts-actions">
                  <button
                    type="button"
                    disabled={!provider.enabled || busy === `test:${provider.id}`}
                    onClick={() => testProvider(provider)}
                  >
                    {busy === `test:${provider.id}` ? "测试中…" : "测试连接"}
                  </button>
                  <button type="button" onClick={() => openDialog(provider)}>编辑</button>
                  <button
                    type="button"
                    className={provider.enabled ? "danger" : ""}
                    disabled={busy === `toggle:${provider.id}`}
                    onClick={() => toggleProvider(provider)}
                  >
                    {provider.enabled ? "停用" : "启用"}
                  </button>
                </div>
              </article>
            ))}
          </section>
        )}

        <p className="admin-overview-privacy admin-accounts-privacy">
          <span className="admin-overview-lock" aria-hidden="true" />
          第三方 API Key 加密保存，保存后不再显示明文
        </p>
      </section>

      {editing && (
        <div className="admin-accounts-dialog-backdrop" onMouseDown={(event) => {
          if (event.target === event.currentTarget && !busy) setEditing(null);
        }}>
          <section className="admin-accounts-dialog admin-ai-dialog" role="dialog" aria-modal="true" aria-labelledby="ai-dialog-title">
            <header>
              <div>
                <h2 id="ai-dialog-title">{editing === "new" ? "添加 AI 服务" : "编辑 AI 服务"}</h2>
                <p>第三方 API 地址与模型保存在后台，API Key 使用服务端密钥加密</p>
              </div>
              <button type="button" aria-label="关闭" disabled={Boolean(busy)} onClick={() => setEditing(null)}>×</button>
            </header>
            <form onSubmit={saveProvider}>
              <div className="admin-ai-dialog-grid">
                <label>
                  服务名称
                  <input
                    name="name"
                    autoFocus
                    required
                    maxLength={80}
                    defaultValue={editing === "new" ? "" : editing.name}
                    placeholder="例如 我的 AI 服务"
                  />
                </label>
                <label>
                  接口协议
                  <select name="kind" defaultValue={editing === "new" ? "openai_compatible" : editing.kind}>
                    <option value="openai_compatible">第三方 API（Responses）</option>
                    <option value="openai_responses">Codex 原生兼容（Responses）</option>
                    {editing !== "new" && editing.kind === "anthropic_compatible" && (
                      <option value="anthropic_compatible" disabled>旧版 Anthropic 配置（请迁移）</option>
                    )}
                  </select>
                </label>
              </div>
              <label>
                API 地址
                <input
                  name="baseUrl"
                  type="url"
                  inputMode="url"
                  required
                  maxLength={400}
                  defaultValue={editing === "new" ? "" : editing.baseUrl}
                  placeholder="https://api.example.com/v1"
                />
              </label>
              <div className="admin-ai-dialog-grid">
                <label>
                  对话模型
                  <input
                    name="textModel"
                    required
                    maxLength={120}
                    defaultValue={editing === "new" ? "" : editing.textModel}
                    placeholder="例如 your-chat-model"
                  />
                </label>
                <label>
                  生图模型（可选）
                  <input
                    name="imageModel"
                    maxLength={120}
                    defaultValue={editing === "new" ? "" : editing.imageModel ?? ""}
                    placeholder="例如 your-image-model"
                  />
                </label>
              </div>
              <label>
                API Key {editing !== "new" && <span className="admin-ai-key-hint">当前 {editing.apiKeyHint}，留空则不更换</span>}
                <input
                  name="apiKey"
                  type="password"
                  required={editing === "new"}
                  maxLength={4096}
                  autoComplete="new-password"
                  placeholder={editing === "new" ? "仅在保存时发送" : "留空保留当前 Key"}
                />
              </label>
              <label className="admin-ai-enabled">
                <input
                  name="enabled"
                  type="checkbox"
                  defaultChecked={editing === "new" ? true : editing.enabled}
                />
                <span>启用此服务</span>
              </label>
              <p className="admin-accounts-dialog-help">第三方接口需兼容 Responses；Codex 原生配置对应 <code>wire_api = &quot;responses&quot;</code>。只允许公网 HTTPS，重定向、内网与本地域名会被拒绝。</p>
              {error && <p className="admin-accounts-dialog-error" role="alert">{error}</p>}
              <footer>
                <button type="button" disabled={Boolean(busy)} onClick={() => setEditing(null)}>取消</button>
                <button className="admin-accounts-primary" disabled={Boolean(busy)}>
                  {busy === "save" ? "正在保存…" : "加密保存"}
                </button>
              </footer>
            </form>
          </section>
        </div>
      )}
    </AdminShell>
  );
}

function kindLabel(kind: Provider["kind"]): string {
  if (kind === "openai_responses") return "Codex Responses 兼容";
  if (kind === "openai_compatible") return "第三方 Responses API";
  return "旧版 Anthropic 配置";
}
