import type { Metadata } from "next";
import Link from "next/link";
import { chatGPTSignInPath, getChatGPTUser } from "../chatgpt-auth";
import { AdminConsole } from "../../components/AdminConsole";

export const metadata: Metadata = { title: "后台管理" };
export const dynamic = "force-dynamic";

export default async function AdminPage() {
  const user = await getChatGPTUser();
  if (!user) {
    return (
      <main className="shell auth-shell">
        <Link className="brand" href="/"><span className="brand-mark">D</span>Daylink</Link>
        <section className="auth-card">
          <p className="eyebrow">ADMIN ACCESS</p>
          <h1>后台配置需要身份确认</h1>
          <p>AI Key、生成资产和分享活动属于受保护数据。登录由托管平台完成，Daylink 不保存你的登录密码。</p>
          <a className="button" href={chatGPTSignInPath("/admin")}>使用 ChatGPT 登录</a>
          <Link className="quiet-link" href="/">返回首页</Link>
        </section>
      </main>
    );
  }

  return <AdminConsole user={{ displayName: user.displayName, email: user.email }} />;
}

