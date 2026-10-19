import { db } from '../database/db';
import { deriveBackupKey } from './auth/pin';

export interface BackupPayload {
  app: 'orange-finance';
  version: 1;
  exportedAt: number;
  data: {
    accounts: unknown[];
    cards: unknown[];
    categories: unknown[];
    transactions: unknown[];
    recurring: unknown[];
    goals: unknown[];
    budgets: unknown[];
    settings: unknown[];
  };
}

export async function buildBackupPayload(): Promise<BackupPayload> {
  const [accounts, cards, categories, transactions, recurring, goals, budgets, settings] = await Promise.all([
    db.accounts.toArray(),
    db.cards.toArray(),
    db.categories.toArray(),
    db.transactions.toArray(),
    db.recurring.toArray(),
    db.goals.toArray(),
    db.budgets.toArray(),
    db.settings.toArray(),
  ]);
  return {
    app: 'orange-finance',
    version: 1,
    exportedAt: Date.now(),
    data: { accounts, cards, categories, transactions, recurring, goals, budgets, settings },
  };
}

function bufToBase64(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)));
}
function base64ToBuf(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

/** Exporta um backup em JSON puro (sem senha) ou criptografado com AES-GCM derivado do PIN informado. */
export async function exportBackup(pin?: string): Promise<Blob> {
  const payload = await buildBackupPayload();
  const json = JSON.stringify(payload);

  if (!pin) {
    return new Blob([json], { type: 'application/json' });
  }

  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveBackupKey(pin, salt);
  const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv: iv as BufferSource }, key, new TextEncoder().encode(json));

  const envelope = {
    app: 'orange-finance',
    encrypted: true,
    salt: bufToBase64(salt.buffer as ArrayBuffer),
    iv: bufToBase64(iv.buffer as ArrayBuffer),
    payload: bufToBase64(encrypted),
  };
  return new Blob([JSON.stringify(envelope)], { type: 'application/json' });
}

export async function importBackup(fileText: string, pin?: string): Promise<{ ok: true } | { ok: false; error: string }> {
  try {
    const parsed = JSON.parse(fileText);
    let payload: BackupPayload;

    if (parsed.encrypted) {
      if (!pin) return { ok: false, error: 'Este backup está protegido por PIN. Informe o PIN para importar.' };
      const salt = base64ToBuf(parsed.salt);
      const iv = base64ToBuf(parsed.iv);
      const key = await deriveBackupKey(pin, salt);
      const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: iv as BufferSource }, key, base64ToBuf(parsed.payload) as BufferSource);
      payload = JSON.parse(new TextDecoder().decode(decrypted));
    } else {
      payload = parsed;
    }

    if (payload.app !== 'orange-finance' || !payload.data) {
      return { ok: false, error: 'Arquivo de backup inválido.' };
    }

    await db.transaction('rw', [db.accounts, db.cards, db.categories, db.transactions, db.recurring, db.goals, db.budgets, db.settings], async () => {
      await Promise.all([
        db.accounts.clear(),
        db.cards.clear(),
        db.categories.clear(),
        db.transactions.clear(),
        db.recurring.clear(),
        db.goals.clear(),
        db.budgets.clear(),
        db.settings.clear(),
      ]);
      await Promise.all([
        db.accounts.bulkAdd(payload.data.accounts as never[]),
        db.cards.bulkAdd(payload.data.cards as never[]),
        db.categories.bulkAdd(payload.data.categories as never[]),
        db.transactions.bulkAdd(payload.data.transactions as never[]),
        db.recurring.bulkAdd(payload.data.recurring as never[]),
        db.goals.bulkAdd(payload.data.goals as never[]),
        db.budgets.bulkAdd(payload.data.budgets as never[]),
        db.settings.bulkAdd(payload.data.settings as never[]),
      ]);
    });

    return { ok: true };
  } catch {
    return { ok: false, error: 'Não foi possível ler este arquivo. Verifique o PIN ou se o arquivo não está corrompido.' };
  }
}

/**
 * Sincronização em nuvem — estrutura preparada para integração futura.
 * Nenhum backend está conectado; esta interface define o contrato que um provedor
 * (ex.: Supabase, Firebase, iCloud/Drive via backend próprio) deverá implementar.
 */
export interface CloudSyncProvider {
  id: string;
  name: string;
  isConnected(): Promise<boolean>;
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  push(payload: BackupPayload): Promise<void>;
  pull(): Promise<BackupPayload | null>;
}

export const cloudSyncRegistry: CloudSyncProvider[] = [];
