import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { logHistory } from '../services/historyLogger';

export function useBudgets() {
  const budgets = useLiveQuery(() => db.budgets.toArray(), []);

  return {
    budgets: budgets ?? [],
    loading: budgets === undefined,
    async setGeneral(amount: number) {
      if (amount <= 0) {
        await db.budgets.delete('general');
        return;
      }
      await db.budgets.put({ id: 'general', amount, createdAt: Date.now() });
      await logHistory('budget', 'general', 'update', 'Orçamento geral definido');
    },
    async setCategory(categoryId: string, amount: number) {
      if (amount <= 0) {
        await db.budgets.delete(categoryId);
        return;
      }
      await db.budgets.put({ id: categoryId, categoryId, amount, createdAt: Date.now() });
      await logHistory('budget', categoryId, 'update', 'Orçamento de categoria definido');
    },
  };
}
