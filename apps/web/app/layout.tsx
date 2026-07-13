import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host") ?? "localhost:3000";
  const protocol = requestHeaders.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const base = new URL(`${protocol}://${host}`);
  const title = "Daylink · SSH 与日程协作";
  const description = "在一个安全工作台中管理服务器、日程、AI 工具与好友出游时间。";
  const image = new URL("/og.png", base).toString();
  return {
    metadataBase: base,
    title: { default: title, template: "%s · Daylink" },
    description,
    openGraph: { title, description, type: "website", images: [{ url: image, width: 1731, height: 909 }] },
    twitter: { card: "summary_large_image", title, description, images: [image] },
  };
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
