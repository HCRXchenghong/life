import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { api } from "./api";

type PollState = {
  poll: { id: string; title: string; description: string; timezone: string; status: string; closesAt: string | null; selectedSlotId: string | null; version: number };
  slots: Array<{ id: string; label: string; startsAt: string; endsAt: string }>;
  participants: Array<{ id: string; displayName: string }>;
  votes: Array<{ participantId: string; slotId: string; response: string }>;
};

export function PollPage({ token }: { token: string }) {
  const [state, setState] = useState<PollState | null>(null);
  const [name, setName] = useState("");
  const [votes, setVotes] = useState<Record<string, string>>({});
  const [message, setMessage] = useState("");
  const editTokenKey = useMemo(() => `daylink_poll_${token}`, [token]);
  const load = useCallback(async () => {
    try { setState(await api<PollState>(`/api/polls/${encodeURIComponent(token)}`)); }
    catch (reason) { setMessage(reason instanceof Error ? reason.message : "投票不存在"); }
  }, [token]);
  useEffect(() => { void load(); }, [load]);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!state) return;
    const selections = state.slots.map((slot) => ({ slotId: slot.id, response: votes[slot.id] ?? "no" }));
    try {
      const receipt = await api<{ editToken: string }>(`/api/polls/${encodeURIComponent(token)}/votes`, {
        method: "POST",
        body: JSON.stringify({ displayName: name, votes: selections, editToken: localStorage.getItem(editTokenKey) || undefined }),
      });
      localStorage.setItem(editTokenKey, receipt.editToken);
      setMessage("选择已保存");
      await load();
    } catch (reason) { setMessage(reason instanceof Error ? reason.message : "保存失败"); }
  }
  if (!state) return <main className="poll-shell"><section className="poll-card"><h1>{message || "正在加载投票…"}</h1></section></main>;
  const open = state.poll.status === "open" && (!state.poll.closesAt || new Date(state.poll.closesAt) > new Date());
  return (
    <main className="poll-shell">
      <section className="poll-card">
        <header className="poll-header"><span className="admin-auth-brand-mark" /><div><p>Daylink · 选时间</p><h1>{state.poll.title}</h1></div></header>
        {state.poll.description && <p className="poll-description">{state.poll.description}</p>}
        <p className="poll-meta">{state.participants.length} 人已参与 · {state.poll.timezone}</p>
        <form onSubmit={submit}>
          <label className="poll-name">你的名字<input value={name} onChange={(event) => setName(event.target.value)} maxLength={80} required disabled={!open} /></label>
          <section className="poll-slots">{state.slots.map((slot) => <article key={slot.id} className={state.poll.selectedSlotId === slot.id ? "selected" : ""}><div><h2>{slot.label || new Date(slot.startsAt).toLocaleDateString("zh-CN")}</h2><p>{new Date(slot.startsAt).toLocaleString("zh-CN")} – {new Date(slot.endsAt).toLocaleTimeString("zh-CN")}</p></div><div className="poll-choice">{["yes", "maybe", "no"].map((value) => <label key={value}><input type="radio" name={slot.id} value={value} checked={(votes[slot.id] ?? "no") === value} onChange={() => setVotes((current) => ({ ...current, [slot.id]: value }))} disabled={!open} />{value === "yes" ? "可以" : value === "maybe" ? "待定" : "不行"}</label>)}</div></article>)}</section>
          {open && <button className="admin-auth-primary">保存选择</button>}
          <p className="admin-auth-message">{message || (open ? "你可以稍后使用同一设备修改选择" : "投票已结束")}</p>
        </form>
      </section>
    </main>
  );
}
