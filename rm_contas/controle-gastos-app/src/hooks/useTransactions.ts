import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { uid } from '../utils/id';
import type { Transaction } from '../models';
import { logHistory } from '../services/historyLogger';
import { monthRange } from '../utils/date';

export type NewTransactionInput = Omit<Transaction, 'id' | 'createdAt' | 'updatedAt' | 'installment'> & {
  installments?: number; // quantidade de parcelas (1 = à vista)
};

export function useTransactions(monthKeyStr: string) {
  const transactions = useLiveQuery(async () => {
    const { start, end } = monthRange(monthKeyStr);
    const startYmd = start.toISOString().slice(0, 10);
    const endYmd = end.toISOString().slice(0, 10);
    const all = await db.transactions.where('date').between(startYmd, endYmd, true, true).toArray();
    return all.sort((a, b) => b.date.localeCompare(a.date) || b.createdAt - a.createdAt);
  }, [monthKeyStr]);

  return {
    transactions: transactions ?? [],
    loading: transactions === undefined,
    ...transactionMutations(),
  };
}

export function useAllTransactions() {
  const transactions = useLiveQuery(() => db.transactions.toArray(), []);
  return { transactions: transactions ?? [], loading: transactions === undefined };
}

export function transactionMutations() {
  return {
    async create(input: NewTransactionInput) {
      const now = Date.now();
      const installmentsCount = Math.max(1, input.installments ?? 1);

      if (installmentsCount === 1) {
        const tx: Transaction = { ...stripInstallments(input), id: uid(), createdAt: now, updatedAt: now };
        await db.transactions.add(tx);
        await logHistory('transaction', tx.id, 'create', describeTx(tx));
        return [tx];
      }

      // Parcelamento: divide o valor total em N parcelas, ajustando centavos na última.
      const group = uid();
      const base = Math.floor(input.amount / installmentsCount);
      const remainder = input.amount - base * installmentsCount;
      const created: Transaction[] = [];
      const [y, m, d] = input.date.split('-').map(Number);

      for (let i = 0; i < installmentsCount; i++) {
        const installDate = new Date(y, m - 1 + i, d);
        const amount = base + (i === installmentsCount - 1 ? remainder : 0);
        const tx: Transaction = {
          ...stripInstallments(input),
          id: uid(),
          amount,
          date: installDate.toISOString().slice(0, 10),
          installment: { group, index: i + 1, total: installmentsCount },
          createdAt: now,
          updatedAt: now,
        };
        created.push(tx);
      }
      await db.transactions.bulkAdd(created);
      await logHistory('transaction', group, 'create', `${describeTx(created[0])} em ${installmentsCount}x`);
      return created;
    },

    async update(id: string, patch: Partial<Transaction>) {
      await db.transactions.update(id, { ...patch, updatedAt: Date.now() });
      await logHistory('transaction', id, 'update', 'Lançamento atualizado');
    },

    async remove(id: string) {
      await db.transactions.delete(id);
      await logHistory('transaction', id, 'delete', 'Lançamento removido');
    },

    async removeInstallmentGroup(group: string) {
      const items = await db.transactions.filter((t) => t.installment?.group === group).toArray();
      await db.transactions.bulkDelete(items.map((t) => t.id));
      await logHistory('transaction', group, 'delete', `${items.length} parcela(s) removida(s)`);
    },

    async markPaid(id: string, paid: boolean) {
      await db.transactions.update(id, { paid, updatedAt: Date.now() });
    },
  };
}

function stripInstallments(input: NewTransactionInput): Omit<Transaction, 'id' | 'createdAt' | 'updatedAt'> {
  const { installments: _installments, ...rest } = input;
  return rest;
}

function describeTx(t: Transaction): string {
  return `${t.type === 'expense' ? 'Despesa' : 'Receita'}: ${t.description || 'sem descrição'}`;
}
