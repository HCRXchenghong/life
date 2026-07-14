import { env } from "cloudflare:workers";
import { base64ToBytes, bytesToBase64 } from "./encoding";
export { createTotpSecret, createTotpUri, verifyTotp } from "./totp";

const encoder = new TextEncoder();
const PASSWORD_ITERATIONS = 600_000;
const PASSWORD_BYTES = 32;

export type PasswordAlgorithm = "pbkdf2-sha256" | "pbkdf2-sha256-app-v1";

type AuthEnv = {
  AUTH_SECRET_MASTER_KEY?: string;
};

export type PasswordDigest = {
  algorithm: PasswordAlgorithm;
  hash: string;
  salt: string;
  iterations: number;
};

export type AuthSecretEnvelope = {
  ciphertext: string;
  nonce: string;
};

function loadAuthRootBytes(): Uint8Array {
  const encoded = (env as unknown as AuthEnv).AUTH_SECRET_MASTER_KEY;
  if (!encoded) throw new Error("Administrator authentication is not configured");
  const raw = base64ToBytes(encoded);
  if (raw.byteLength !== 32) {
    throw new Error("AUTH_SECRET_MASTER_KEY must be a base64-encoded 32-byte key");
  }
  return raw;
}

async function deriveBytes(label: string): Promise<Uint8Array> {
  const root = await crypto.subtle.importKey(
    "raw",
    asArrayBuffer(loadAuthRootBytes()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", root, encoder.encode(label)));
}

function joinBytes(first: Uint8Array, second: Uint8Array): Uint8Array {
  const joined = new Uint8Array(first.byteLength + second.byteLength);
  joined.set(first, 0);
  joined.set(second, first.byteLength);
  return joined;
}

async function passwordMaterial(
  password: string,
  algorithm: PasswordAlgorithm,
): Promise<Uint8Array> {
  const label = algorithm === "pbkdf2-sha256-app-v1"
    ? "daylink:app-password-pepper:v1"
    : "daylink:password-pepper:v1";
  return joinBytes(encoder.encode(password), await deriveBytes(label));
}

async function pbkdf2(
  password: string,
  salt: Uint8Array,
  iterations: number,
  algorithm: PasswordAlgorithm,
): Promise<Uint8Array> {
  const material = await crypto.subtle.importKey(
    "raw",
    asArrayBuffer(await passwordMaterial(password, algorithm)),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  return new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "PBKDF2", hash: "SHA-256", salt: asArrayBuffer(salt), iterations },
      material,
      PASSWORD_BYTES * 8,
    ),
  );
}

export async function hashPassword(
  password: string,
  purpose: "admin" | "app" = "admin",
): Promise<PasswordDigest> {
  const algorithm: PasswordAlgorithm = purpose === "app"
    ? "pbkdf2-sha256-app-v1"
    : "pbkdf2-sha256";
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, PASSWORD_ITERATIONS, algorithm);
  return {
    algorithm,
    hash: bytesToBase64(hash),
    salt: bytesToBase64(salt),
    iterations: PASSWORD_ITERATIONS,
  };
}

export async function verifyPassword(
  password: string,
  digest: Pick<PasswordDigest, "algorithm" | "hash" | "salt" | "iterations">,
): Promise<boolean> {
  if (digest.algorithm !== "pbkdf2-sha256" && digest.algorithm !== "pbkdf2-sha256-app-v1") {
    return false;
  }
  if (digest.iterations < PASSWORD_ITERATIONS || digest.iterations > 2_000_000) return false;
  const expected = base64ToBytes(digest.hash);
  const salt = base64ToBytes(digest.salt);
  if (expected.byteLength !== PASSWORD_BYTES || salt.byteLength < 16) return false;
  const actual = await pbkdf2(password, salt, digest.iterations, digest.algorithm);
  return constantTimeEqual(actual, expected);
}

export async function encryptAuthSecret(
  plaintext: string,
  context: string,
): Promise<AuthSecretEnvelope> {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const key = await crypto.subtle.importKey(
    "raw",
    asArrayBuffer(loadAuthRootBytes()),
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, additionalData: encoder.encode(context) },
    key,
    encoder.encode(plaintext),
  );
  return {
    ciphertext: bytesToBase64(new Uint8Array(ciphertext)),
    nonce: bytesToBase64(nonce),
  };
}

export async function decryptAuthSecret(
  envelope: AuthSecretEnvelope,
  context: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    asArrayBuffer(loadAuthRootBytes()),
    { name: "AES-GCM" },
    false,
    ["decrypt"],
  );
  const plaintext = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: asArrayBuffer(base64ToBytes(envelope.nonce)),
      additionalData: encoder.encode(context),
    },
    key,
    asArrayBuffer(base64ToBytes(envelope.ciphertext)),
  );
  return new TextDecoder().decode(plaintext);
}

export function randomToken(byteLength = 32): string {
  return bytesToBase64Url(crypto.getRandomValues(new Uint8Array(byteLength)));
}

export async function hashOpaqueToken(token: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(token)));
  return bytesToBase64Url(bytes);
}

export async function hashPrivateIdentifier(purpose: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    asArrayBuffer(await deriveBytes(`daylink:identifier:${purpose}:v1`)),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return bytesToBase64Url(new Uint8Array(digest));
}

function constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.byteLength === 0 || right.byteLength === 0) return false;
  const length = Math.max(left.byteLength, right.byteLength);
  let difference = left.byteLength ^ right.byteLength;
  for (let index = 0; index < length; index += 1) {
    difference |= (left[index % left.byteLength] ?? 0) ^ (right[index % right.byteLength] ?? 0);
  }
  return difference === 0;
}

function asArrayBuffer(value: Uint8Array): ArrayBuffer {
  const copy = Uint8Array.from(value);
  return copy.buffer;
}

function bytesToBase64Url(value: Uint8Array): string {
  return bytesToBase64(value).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
