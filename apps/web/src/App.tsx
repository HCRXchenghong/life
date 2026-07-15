import { useCallback, useEffect, useState } from "react";
import { api, navigate } from "./api";
import { AdminEnrollment, AdminLogin, AdminSetup, PendingSetup } from "./Auth";
import { Dashboard } from "./Dashboard";
import { PollPage } from "./PollPage";

type Bootstrap = {
  state: "uninitialized" | "pending" | "enrollment" | "login" | "authenticated";
  username?: string;
};

export function App() {
  const [path, setPath] = useState(window.location.pathname);
  const [bootstrap, setBootstrap] = useState<Bootstrap | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    const update = () => setPath(window.location.pathname);
    window.addEventListener("popstate", update);
    return () => window.removeEventListener("popstate", update);
  }, []);

  const reload = useCallback(async () => {
    try {
      setError("");
      setBootstrap(await api<Bootstrap>("/api/admin/bootstrap"));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "无法连接后台服务");
    }
  }, []);

  useEffect(() => {
    if (path.startsWith("/poll/")) return;
    void reload();
  }, [path, reload]);

  if (path.startsWith("/poll/")) {
    return <PollPage token={path.slice("/poll/".length)} />;
  }
  if (error) {
    return <StatePage title="后台暂时不可用" detail={error} action={() => void reload()} />;
  }
  if (!bootstrap) {
    return <StatePage title="正在连接后台" detail="请稍候" />;
  }
  if (bootstrap.state === "uninitialized") {
    return <AdminSetup onCreated={() => { navigate("/admin/setup/2fa"); void reload(); }} />;
  }
  if (bootstrap.state === "enrollment") {
    return <AdminEnrollment onComplete={() => { navigate("/admin"); void reload(); }} onRestart={() => { navigate("/admin"); void reload(); }} />;
  }
  if (bootstrap.state === "pending") {
    return <PendingSetup />;
  }
  if (bootstrap.state === "login") {
    return <AdminLogin onLogin={() => { navigate("/admin"); void reload(); }} />;
  }
  return <Dashboard username={bootstrap.username ?? "admin"} path={path} onLogout={() => void reload()} />;
}

function StatePage({ title, detail, action }: { title: string; detail: string; action?: () => void }) {
  return (
    <main className="admin-auth-shell">
      <Brand />
      <section className="admin-auth-content">
        <h1>{title}</h1>
        <p className="admin-auth-subtitle">{detail}</p>
        {action && <button className="admin-auth-primary" onClick={action}>重试</button>}
      </section>
    </main>
  );
}

export function Brand() {
  return (
    <a className="admin-auth-brand" href="/admin" onClick={(event) => { event.preventDefault(); navigate("/admin"); }}>
      <span className="admin-auth-brand-mark" aria-hidden="true" />
      <span>Daylink</span>
    </a>
  );
}
