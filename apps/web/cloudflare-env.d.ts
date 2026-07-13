/// <reference types="@cloudflare/workers-types" />

interface DaylinkWorkerEnv {
  ASSETS: Fetcher;
  DB: D1Database;
  GENERATED_ASSETS: R2Bucket;
  IMAGES: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: {
          format: string;
          quality: number;
        }): Promise<{ response(): Response }>;
      };
    };
  };
  AI_SECRET_MASTER_KEY?: string;
  SHARE_API_TOKEN?: string;
}

declare module "cloudflare:workers" {
  export const env: DaylinkWorkerEnv;
}

