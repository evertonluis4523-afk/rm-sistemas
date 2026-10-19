/**
 * Desbloqueio biométrico (Face ID / Touch ID / impressão digital) via WebAuthn,
 * usando o autenticador de plataforma do próprio aparelho.
 *
 * Modelo de confiança: como o app não possui servidor, este fluxo NÃO faz verificação
 * criptográfica de assinatura contra uma chave pública remota (isso exigiria um backend).
 * Em vez disso, usamos o WebAuthn como um "portão" local: registramos uma credencial no
 * autenticador de plataforma do aparelho e, no desbloqueio, exigimos que o mesmo
 * autenticador aprove um desafio (Face ID/Touch ID/impressão digital). O PIN continua
 * sendo o mecanismo principal e sempre disponível como alternativa.
 */

const RP_NAME = 'Carteira Everton';

export function isWebAuthnSupported(): boolean {
  return typeof window !== 'undefined' && !!window.PublicKeyCredential;
}

export async function isPlatformAuthenticatorAvailable(): Promise<boolean> {
  if (!isWebAuthnSupported()) return false;
  try {
    return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
  } catch {
    return false;
  }
}

function randomChallenge(): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(32));
}

function textToBuffer(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

function bufToBase64Url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlToBuf(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/').padEnd(b64url.length + ((4 - (b64url.length % 4)) % 4), '=');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

/** Registra uma credencial biométrica local. Retorna o ID (base64url) para salvar nas configurações. */
export async function registerBiometric(userLabel: string): Promise<string | null> {
  if (!isWebAuthnSupported()) return null;
  try {
    const credential = (await navigator.credentials.create({
      publicKey: {
        challenge: randomChallenge() as BufferSource,
        rp: { name: RP_NAME },
        user: { id: textToBuffer(userLabel) as BufferSource, name: userLabel, displayName: userLabel },
        pubKeyCredParams: [
          { type: 'public-key', alg: -7 }, // ES256
          { type: 'public-key', alg: -257 }, // RS256
        ],
        authenticatorSelection: { authenticatorAttachment: 'platform', userVerification: 'required' },
        timeout: 60_000,
        attestation: 'none',
      },
    })) as PublicKeyCredential | null;
    if (!credential) return null;
    return bufToBase64Url(credential.rawId);
  } catch {
    return null;
  }
}

/** Solicita a aprovação biométrica para a credencial registrada. */
export async function verifyBiometric(credentialId: string): Promise<boolean> {
  if (!isWebAuthnSupported()) return false;
  try {
    const assertion = await navigator.credentials.get({
      publicKey: {
        challenge: randomChallenge() as BufferSource,
        allowCredentials: [{ id: base64UrlToBuf(credentialId) as BufferSource, type: 'public-key', transports: ['internal'] }],
        userVerification: 'required',
        timeout: 60_000,
      },
    });
    return !!assertion;
  } catch {
    return false;
  }
}
