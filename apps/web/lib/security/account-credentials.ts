const USERNAME_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{3,31}$/;

export function validateAccountUsername(value: unknown, label = "账号"): string {
  if (typeof value !== "string") throw new Error(`请输入${label}`);
  const username = value.trim();
  if (!USERNAME_PATTERN.test(username)) {
    throw new Error(`${label}需为 4–32 位字母、数字、点、横线或下划线`);
  }
  return username;
}

export function canonicalAccountUsername(username: string): string {
  return username.toLowerCase();
}

export function validateStrongPassword(value: unknown): string {
  if (typeof value !== "string" || value.length < 12 || value.length > 128) {
    throw new Error("密码长度需为 12–128 位");
  }
  if (!/[a-z]/.test(value) || !/[A-Z]/.test(value) || !/\d/.test(value) || !/[^A-Za-z0-9]/.test(value)) {
    throw new Error("密码需包含大小写字母、数字和符号");
  }
  return value;
}

export function validatePresentedPassword(value: unknown): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 128) {
    throw new Error("账号或密码不正确");
  }
  return value;
}

export function validateDeviceName(value: unknown): string {
  if (typeof value !== "string") return "未命名设备";
  const normalized = value.trim();
  if (!normalized) return "未命名设备";
  if (normalized.length > 80) throw new Error("设备名称过长");
  return normalized;
}

export function readBearerToken(header: string | null): string | null {
  if (!header?.startsWith("Bearer ")) return null;
  const token = header.slice("Bearer ".length).trim();
  if (token.length < 32 || token.length > 256 || !/^[A-Za-z0-9_-]+$/.test(token)) {
    return null;
  }
  return token;
}
