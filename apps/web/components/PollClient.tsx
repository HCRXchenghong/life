"use client";

import { FormEvent, useMemo, useState } from "react";

type PollData = {
  poll: { id: string; title: string; description: string; timezone: string; status: string; closesAt: string | null; selectedSlotId: string | null };
  slots: Array<{ id: string; label: string; startsAt: string; endsAt: string }>;
  participants: Array<{ id: string; displayName: string }>;
  votes: Array<{ participantId: string; slotId: string; response: "yes" | "maybe" | "no" }>;
};

export function PollClient({ token, initial }: { token: string; initial: PollData }) {
  const [data, setData] = useState(initial);
  const [name, setName] = useState("");
  const [votes, setVotes] = useState<Record<string, "yes" | "maybe" | "no">>({});
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const closed = data.poll.status !== "open" || Boolean(data.poll.closesAt && new Date(data.poll.closesAt) <= new Date());

  const counts = useMemo(() => Object.fromEntries(data.slots.map((slot) => {
    const slotVotes = data.votes.filter((vote) => vote.slotId === slot.id);
    return [slot.id, { yes: slotVotes.filter((vote) => vote.response === "yes").length, maybe: slotVotes.filter((vote) => vote.response === "maybe").length }];
  })), [data]);

  async function submit(event: FormEvent) {
    event.preventDefault(); setBusy(true); setMessage("");
    const response = await fetch(`/api/polls/${token}/votes`, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ displayName: name, votes: Object.entries(votes).map(([slotId, value]) => ({ slotId, response: value })) }),
    });
    const result = (await response.json()) as { error?: { message?: string } }; setBusy(false);
    if (!response.ok) return setMessage(result.error?.message ?? "提交失败");
    setMessage("选择已保存。你可以在这台设备上再次提交来修改。");
    const refreshed = await fetch(`/api/polls/${token}`, { cache: "no-store" });
    if (refreshed.ok) setData((await refreshed.json()) as PollData);
  }

  return <section className="poll-card">
    <header className="poll-heading"><p className="eyebrow">PICK A TIME</p><h1>{data.poll.title}</h1>{data.poll.description && <p>{data.poll.description}</p>}<div className="poll-meta"><span>{data.slots.length} 个候选时间</span><span>{data.participants.length} 人已参与</span><span>{data.poll.timezone}</span></div></header>
    {data.poll.selectedSlotId && <div className="selected-banner">最终时间已经确定：{formatSlot(data.slots.find((slot) => slot.id === data.poll.selectedSlotId)!, data.poll.timezone)}</div>}
    <form onSubmit={submit}>
      <label className="name-field">你的称呼<input value={name} onChange={(event) => setName(event.target.value)} required maxLength={80} disabled={closed} placeholder="例如：小林" /></label>
      <div className="slot-list">{data.slots.map((slot) => <article className={`slot-card ${data.poll.selectedSlotId === slot.id ? "selected" : ""}`} key={slot.id}><div className="slot-time"><time>{formatSlot(slot, data.poll.timezone)}</time>{slot.label && <span>{slot.label}</span>}<small>{counts[slot.id]?.yes ?? 0} 可以 · {counts[slot.id]?.maybe ?? 0} 待定</small></div><div className="vote-options" role="radiogroup" aria-label={formatSlot(slot, data.poll.timezone)}>{(["yes", "maybe", "no"] as const).map((value) => <button key={value} type="button" role="radio" aria-checked={votes[slot.id] === value} className={votes[slot.id] === value ? "chosen" : ""} onClick={() => setVotes((current) => ({ ...current, [slot.id]: value }))} disabled={closed}>{value === "yes" ? "可以" : value === "maybe" ? "待定" : "不行"}</button>)}</div></article>)}</div>
      {message && <p className="poll-message" role="status">{message}</p>}
      <button className="button poll-submit" disabled={closed || busy || Object.keys(votes).length === 0}>{closed ? "投票已结束" : busy ? "保存中…" : "提交选择"}</button>
    </form>
    {data.participants.length > 0 && <div className="participant-strip"><span>已参与</span>{data.participants.map((person) => <span className="participant" key={person.id}>{person.displayName.slice(0, 1)}</span>)}</div>}
  </section>;
}

function formatSlot(slot: { startsAt: string; endsAt: string }, timezone: string) {
  const formatter = new Intl.DateTimeFormat("zh-CN", { timeZone: timezone, month: "long", day: "numeric", weekday: "short", hour: "2-digit", minute: "2-digit" });
  const endFormatter = new Intl.DateTimeFormat("zh-CN", { timeZone: timezone, hour: "2-digit", minute: "2-digit" });
  return `${formatter.format(new Date(slot.startsAt))}–${endFormatter.format(new Date(slot.endsAt))}`;
}
