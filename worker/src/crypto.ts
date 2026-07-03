// WebCrypto helpers for the device-auth flow (CLAUDE.md §12).
// Token format: `${userId}.${issuedAt}.${sig}` — no JWT library needed.

const encoder = new TextEncoder();

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(input));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

function toBase64Url(bytes: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(bytes)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

export async function signToken(userId: string, issuedAt: number, signingKey: string): Promise<string> {
  const key = await hmacKey(signingKey);
  const payload = `${userId}.${issuedAt}`;
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  return `${payload}.${toBase64Url(sig)}`;
}

export async function verifyToken(
  token: string,
  signingKey: string,
): Promise<{ userId: string; issuedAt: number } | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [userId, issuedAtRaw, sig] = parts;
  const issuedAt = Number(issuedAtRaw);
  if (!userId || !issuedAtRaw || !sig || !Number.isFinite(issuedAt)) return null;

  const key = await hmacKey(signingKey);
  const expected = await crypto.subtle.sign("HMAC", key, encoder.encode(`${userId}.${issuedAtRaw}`));
  const expectedB64 = toBase64Url(expected);

  if (!timingSafeEqual(expectedB64, sig)) return null;
  return { userId, issuedAt };
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}
