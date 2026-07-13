import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { PollClient } from "../../../components/PollClient";
import { loadPollByPublicToken } from "../../../lib/polls/service";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "选择活动时间", robots: { index: false, follow: false } };

export default async function PollPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const result = await loadPollByPublicToken(token);
  if (!result) notFound();
  return (
    <main className="poll-shell">
      <nav className="poll-nav"><Link className="brand" href="/"><span className="brand-mark">D</span>Daylink</Link><span>好友时间协调</span></nav>
      <PollClient token={token} initial={result} />
      <p className="poll-privacy">只提交你为本次活动选择的时间；Daylink 不读取或上传你的个人日历。</p>
    </main>
  );
}

