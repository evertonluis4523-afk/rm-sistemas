import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { uid } from '../utils/id';
import type { Account } from '../models';
import { logHistory } from '../services/historyLogger';

/** Mapa id→nome de conta, para exibir "Categoria | Conta" nas linhas de transação. */
export function useAccountNameMap(): Map<string, string> {
  const accounts = useLiveQuery(() => db.accounts.toArray(), []);
  return new Map((accounts ?? []).map((a) => [a.id, a.name]));
}

export function useAccounts(includeArchived = false) {
  const accounts = useLiveQuery(async () => {
    const all = (await db.accounts.toArray()).sort((a, b) => a.createdAt - b.createdAt);
    return includeArchived ? all : all.filter((a) => !a.archived);
  }, [includeArchived]);

  return {
    accounts: accounts ?? [],
    loading: accounts === undefined,
    async create(data: Omit<Account, 'id' | 'createdAt' | 'updatedAt' | 'archived'>) {
      const now = Date.now();
      const account: Account = { ...data, id: uid(), archived: false, createdAt: now, updatedAt: now };
      await db.accounts.add(account);
      await logHistory('account', account.id, 'create', `Conta criada: ${account.name}`);
      return account;
    },
    async update(id: string, patch: Partial<Account>) {
      await db.accounts.update(id, { ...patch, updatedAt: Date.now() });
      await logHistory('account', id, 'update', 'Conta atualizada');
    },
    async archive(id: string) {
      await db.accounts.update(id, { archived: true, updatedAt: Date.now() });
      await logHistory('account', id, 'delete', 'Conta arquivada');
    },
    async remove(id: string) {
      await db.accounts.delete(id);
      await logHistory('account', id, 'delete', 'Conta removida');
    },
  };
}
