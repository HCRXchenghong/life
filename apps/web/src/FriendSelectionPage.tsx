import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { api } from "./api";

type TimeRange = { id: string; label: string; startsAt: string; endsAt: string };
type Selection = { id: string; startsAt: string; endsAt: string };
type InviteState = {
  poll: {
    id: string;
    title: string;
    description: string;
    timezone: string;
    status: string;
    closesAt: string | null;
  };
  invite: { id: string; displayName: string; status: string };
  ranges: TimeRange[];
  selections: Selection[];
};
type TimeBlock = { id: string; rangeId: string; startsAt: Date; endsAt: Date };

export function FriendSelectionPage({ token }: { token: string }) {
  const [state, setState] = useState<InviteState | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const value = await api<InviteState>(`/api/poll-invites/${encodeURIComponent(token)}`);
      setState(value);
      setMessage("");
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "专属邀请不可用");
    }
  }, [token]);

  useEffect(() => { void load(); }, [load]);

  const blocks = useMemo(() => state ? makeBlocks(state.ranges) : [], [state]);

  useEffect(() => {
    if (!state) return;
    const restored = new Set<string>();
    for (const block of blocks) {
      if (state.selections.some((value) => block.startsAt >= new Date(value.startsAt) && block.endsAt <= new Date(value.endsAt))) {
        restored.add(block.id);
      }
    }
    setSelected(restored);
  }, [blocks, state]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!state || selected.size === 0) return;
    setBusy(true);
    setMessage("");
    try {
      await api(`/api/poll-invites/${encodeURIComponent(token)}/selections`, {
        method: "PUT",
        body: JSON.stringify({ selections: mergeBlocks(blocks.filter((block) => selected.has(block.id))) }),
      });
      await load();
      setMessage("选择已保存，可以关闭这个页面了");
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "暂时无法保存选择");
    } finally {
      setBusy(false);
    }
  }

  if (!state) {
    return <main className="friend-select-shell"><section className="friend-select-card friend-select-state"><span className="admin-auth-brand-mark" /><h1>{message || "正在打开专属邀请…"}</h1>{message && <button onClick={() => void load()}>重试</button>}</section></main>;
  }

  const open = state.poll.status === "open" && (!state.poll.closesAt || new Date(state.poll.closesAt) > new Date());
  return (
    <main className="friend-select-shell">
      <section className="friend-select-card">
        <header className="friend-select-brand"><span className="admin-auth-brand-mark" /><span>Daylink</span></header>
        <div className="friend-select-heading">
          <p>{state.invite.displayName}，请选择你方便的时间</p>
          <h1>{state.poll.title}</h1>
          {state.poll.description && <span>{state.poll.description}</span>}
        </div>
        <div className="friend-select-tip"><strong>可单选，也可多选</strong><span>只会向活动发起人提交你的选择</span></div>
        <form onSubmit={submit}>
          <div className="friend-select-ranges">
            {state.ranges.map((range) => {
              const values = blocks.filter((block) => block.rangeId === range.id);
              return <section key={range.id} className="friend-select-range">
                <header><h2>{formatDay(range.startsAt, state.poll.timezone)}</h2>{range.label && <span>{range.label}</span>}</header>
                <div className="friend-select-blocks">
                  {values.map((block) => <button
                    type="button"
                    key={block.id}
                    aria-pressed={selected.has(block.id)}
                    disabled={!open || busy}
                    onClick={() => setSelected((current) => toggle(current, block.id))}
                  >{formatTime(block.startsAt, state.poll.timezone)}–{formatTime(block.endsAt, state.poll.timezone)}</button>)}
                </div>
              </section>;
            })}
          </div>
          <div className="friend-select-footer">
            <span>已选择 {selected.size} 段</span>
            {open ? <button className="friend-select-submit" disabled={busy || selected.size === 0}>{busy ? "保存中…" : "提交选择"}</button> : <strong>活动已结束</strong>}
          </div>
          <p className="friend-select-message" role="status">{message}</p>
        </form>
      </section>
    </main>
  );
}

function makeBlocks(ranges: TimeRange[]): TimeBlock[] {
  const result: TimeBlock[] = [];
  for (const range of ranges) {
    const rangeEnd = new Date(range.endsAt);
    let cursor = new Date(range.startsAt);
    while (cursor < rangeEnd) {
      const end = new Date(Math.min(cursor.getTime() + 30 * 60_000, rangeEnd.getTime()));
      result.push({ id: `${range.id}:${cursor.toISOString()}`, rangeId: range.id, startsAt: cursor, endsAt: end });
      cursor = end;
    }
  }
  return result;
}

function mergeBlocks(blocks: TimeBlock[]) {
  const sorted = [...blocks].sort((left, right) => left.startsAt.getTime() - right.startsAt.getTime());
  const result: Array<{ startsAt: string; endsAt: string; rangeId: string }> = [];
  for (const block of sorted) {
    const previous = result.at(-1);
    if (previous && previous.rangeId === block.rangeId && previous.endsAt === block.startsAt.toISOString()) {
      previous.endsAt = block.endsAt.toISOString();
    } else {
      result.push({ rangeId: block.rangeId, startsAt: block.startsAt.toISOString(), endsAt: block.endsAt.toISOString() });
    }
  }
  return result.map(({ startsAt, endsAt }) => ({ startsAt, endsAt }));
}

function toggle(current: Set<string>, id: string) {
  const next = new Set(current);
  if (next.has(id)) next.delete(id); else next.add(id);
  return next;
}

function formatDay(value: string, timezone: string) {
  return new Intl.DateTimeFormat("zh-CN", { timeZone: timezone, month: "long", day: "numeric", weekday: "short" }).format(new Date(value));
}

function formatTime(value: Date, timezone: string) {
  return new Intl.DateTimeFormat("zh-CN", { timeZone: timezone, hour: "2-digit", minute: "2-digit", hour12: false }).format(value);
}
