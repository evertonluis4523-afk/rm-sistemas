import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';

/**
 * Saldo atual de cada conta = saldo inicial + receitas vinculadas - despesas vinculadas
 * (contas futuras não pagas não entram na conta, só quando marcadas como pagas).
 */
export function useAccountBalances() {
  return useLiveQuery(async () => {
    const [accounts, transactions] = await Promise.all([db.accounts.toArray(), db.transactions.toArray()]);
    const map = new Map<string, number>();
    accounts.forEach((a) => map.set(a.id, a.balance));

    transactions.forEach((t) => {
      if (!t.accountId) return;
      if (t.type === 'expense' && !t.paid) return; // conta futura ainda não paga não afeta o saldo
      const current = map.get(t.accountId) ?? 0;
      map.set(t.accountId, current + (t.type === 'income' ? t.amount : -t.amount));
    });

    const total = [...map.values()].reduce((s, v) => s + v, 0);
    return { balances: map, total };
  }, []) ?? { balances: new Map<string, number>(), total: 0 };
}
