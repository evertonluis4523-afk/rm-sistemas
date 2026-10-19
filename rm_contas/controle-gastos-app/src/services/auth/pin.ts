/**
 * Proteção por PIN local. O PIN nunca é armazenado em texto puro: derivamos uma chave
 * PBKDF2-SHA256 (100k iterações) com salt aleatório e comparamos hashes.
 * Modelo de confiança: proteção de sessão local (dispositivo do usuário), não autenticação
 * de identidade remota — adequado para um app 100% offline, sem servidor.
 */

const PBKDF2_ITERATIONS = 100_000;

function toBase64(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)));
}
function fromBase64(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function deriveHash(pin: string, salt: Uint8Array): Promise<string> {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey('raw', enc.encode(pin), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: salt as BufferSource, iterations: PBKDF2_ITERATIONS, hash: 'SHA-256' },
    keyMaterial,
    256
  );
  return toBase64(bits);
}

export async function hashPin(pin: string): Promise<{ hash: string; salt: string }> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await deriveHash(pin, salt);
  return { hash, salt: toBase64(salt.buffer as ArrayBuffer) };
}

export async function verifyPin(pin: string, hash: string, salt: string): Promise<boolean> {
  const saltBytes = fromBase64(salt);
  const candidate = await deriveHash(pin, saltBytes);
  return timingSafeEqual(candidate, hash);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Deriva uma chave AES-GCM a partir do PIN, usada para criptografar backups exportados. */
export async function deriveBackupKey(pin: string, salt: Uint8Array): Promise<CryptoKey> {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey('raw', enc.encode(pin), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt: salt as BufferSource, iterations: PBKDF2_ITERATIONS, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

export const MAX_PIN_ATTEMPTS = 5;
export const LOCKOUT_MS = 60_000;
