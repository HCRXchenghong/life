import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, ".", "");
  return {
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        "/api": {
          target: env.DAYLINK_DEV_API || "http://127.0.0.1:8080",
          secure: false,
        },
      },
    },
    build: {
      outDir: "dist",
      sourcemap: false,
    },
  };
});
