import { env } from "cloudflare:workers";
import { base64ToBytes, bytesToBase64 } from "./encoding";

type SecretEnvelope = {
  ciphertext: string;
  nonce: string;
};

type DaylinkEnv = {
  AI_SECRET_MASTER_KEY?: string;
};

const encoder = new TextEncoder();
const decoder = new TextDecoder();

async function loadMasterKey(): Promise<CryptoKey> {
  const encoded = (env as unknown as DaylinkEnv).AI_SECRET_MASTER_KEY;
  if (!encoded) {
    throw new Error("AI secret storage is not configured");
  }
  const raw = base64ToBytes(encoded);
  if (raw.byteLength !== 32) {
    throw new Error("AI_SECRET_MASTER_KEY must be a base64-encoded 32-byte key");
  }
  return crypto.subtle.importKey("raw", raw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
}

export async function encryptSecret(
  plaintext: string,
  ownerEmail: string,
): Promise<SecretEnvelope> {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const key = await loadMasterKey();
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, additionalData: encoder.encode(ownerEmail) },
    key,
    encoder.encode(plaintext),
  );
  return {
    ciphertext: bytesToBase64(new Uint8Array(ciphertext)),
    nonce: bytesToBase64(nonce),
  };
}

export async function decryptSecret(
  envelope: SecretEnvelope,
  ownerEmail: string,
): Promise<string> {
  const key = await loadMasterKey();
  const plaintext = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: base64ToBytes(envelope.nonce),
      additionalData: encoder.encode(ownerEmail),
    },
    key,
    base64ToBytes(envelope.ciphertext),
  );
  return decoder.decode(plaintext);
}

export function secretHint(secret: string): string {
  if (secret.length <= 4) return "••••";
  return `••••${secret.slice(-4)}`;
}

