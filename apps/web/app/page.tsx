import Link from "next/link";

const capabilities = [
  ["SSH Core", "持久终端、文件、监控、端口转发与远端 Agent"],
  ["Schedule", "本地优先日程、重复规则、冲突检测与系统原生提醒"],
  ["AI Tools", "可配置 Provider、严格工具 schema、审批、审计与生图"],
  ["Time Poll", "生成邀请链接，让朋友不安装 App 也能选择时间"],
];

export default function Home() {
  return (
    <main className="shell landing">
      <nav className="topbar" aria-label="主导航">
        <Link className="brand" href="/">
          <span className="brand-mark">D</span>
          <span>Daylink</span>
        </Link>
        <div className="nav-actions">
          <a href="/api/health" className="quiet-link">API 状态</a>
          <Link href="/admin" className="button button-small">进入后台</Link>
        </div>
      </nav>

      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">SSH × CALENDAR × AI</p>
          <h1>把服务器和生活安排，放进同一个可信工作台。</h1>
          <p className="hero-lead">
            Daylink 连接你的 Linux 主机，也理解“周六下午和朋友出去”这样的自然语言。
            它负责执行、提醒、协调，但每一步敏感操作仍由你掌控。
          </p>
          <div className="hero-actions">
            <Link href="/admin" className="button">配置 AI 与分享服务</Link>
            <a href="#architecture" className="button button-ghost">查看能力边界</a>
          </div>
          <div className="status-line">
            <span className="pulse" /> 后台服务基线已启用
            <span>Android / iOS / Web / Linux Agent</span>
          </div>
        </div>

        <div className="hero-panel" aria-label="Daylink 运行概览">
          <div className="panel-head"><span>今天</span><span className="mono">ASIA/SHANGHAI</span></div>
          <div className="timeline-item active">
            <time>09:30</time>
            <div><strong>生产环境巡检</strong><p>3 台主机 · 只读工具 · 已完成</p></div>
            <span className="state ok">OK</span>
          </div>
          <div className="timeline-item">
            <time>14:00</time>
            <div><strong>项目深度工作</strong><p>提前 10 分钟原生提醒</p></div>
            <span className="state">日程</span>
          </div>
          <div className="timeline-item">
            <time>19:30</time>
            <div><strong>周末出游投票截止</strong><p>6 位朋友 · 3 个候选时间</p></div>
            <span className="state warm">投票</span>
          </div>
          <div className="command-strip mono">
            <span>$</span><span>agent status --all</span><span className="cursor" />
          </div>
        </div>
      </section>

      <section id="architecture" className="capability-grid" aria-label="产品能力">
        {capabilities.map(([title, description], index) => (
          <article key={title} className="capability-card">
            <span className="card-number">0{index + 1}</span>
            <h2>{title}</h2>
            <p>{description}</p>
          </article>
        ))}
      </section>

      <section className="boundary">
        <div>
          <p className="eyebrow">SECURITY MODEL</p>
          <h2>像 Codex 一样，把能力和批准分开。</h2>
        </div>
        <p>
          工具是否“能做”由沙箱和能力白名单决定，工具何时“可以做”由批准策略决定。
          SSH 私钥、AI Key 和管理令牌不会进入模型上下文；高风险动作不能取消确认。
        </p>
      </section>
    </main>
  );
}

