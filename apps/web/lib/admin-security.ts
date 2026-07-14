import { eq } from "drizzle-orm";
import { getDb } from "../db";
import { adminAccounts } from "../db/schema";
import type { AdminIdentity } from "./admin-auth";
import { decryptAuthSecret, verifyPassword, verifyTotp } from "./security/auth-crypto";

export type AdminStepUp = {
  acceptedCounter: number;
};

export async function verifyAdminStepUp(
  identity: AdminIdentity,
  currentPassword: string,
  currentCode: string,
): Promise<AdminStepUp | null> {
  if (
    currentPassword.length === 0 ||
    currentPassword.length > 128 ||
    !/^\d{6}$/.test(currentCode)
  ) {
    return null;
  }
  const [account] = await getDb()
    .select()
    .from(adminAccounts)
    .where(eq(adminAccounts.id, identity.id))
    .limit(1);
  if (!account || account.status !== "active") return null;

  const passwordOk = await verifyPassword(currentPassword, {
    algorithm: account.passwordAlgorithm as Parameters<typeof verifyPassword>[1]["algorithm"],
    hash: account.passwordHash,
    salt: account.passwordSalt,
    iterations: account.passwordIterations,
  });
  if (!passwordOk) return null;

  const secret = await decryptAuthSecret(
    { ciphertext: account.totpSecretCiphertext, nonce: account.totpSecretNonce },
    `admin-totp:${account.id}`,
  );
  const acceptedCounter = await verifyTotp(secret, currentCode, account.totpLastCounter);
  return acceptedCounter === null ? null : { acceptedCounter };
}
