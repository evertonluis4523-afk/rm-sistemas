import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { uid } from '../utils/id';
import type { Recurring } from '../models';
import { logHistory } from '../services/historyLogger';

export function useRecurring() {
  const recurring = useLiveQuery(async () => (await db.recurring.toArray()).sort((a, b) => a.createdAt - b.createdAt), []);

  return {
    recurring: recurring ?? [],
    loading: recurring === undefined,
    async create(data: Omit<Recurring, 'id' | 'createdAt' | 'active'>) {
      const item: Recurring = { ...data, id: uid(), active: true, createdAt: Date.now() };
      await db.recurring.add(item);
      await logHistory('recurring', item.id, 'create', 'Gasto fixo criado');
      return item;
    },
    async toggle(id: string, active: boolean) {
      await db.recurring.update(id, { active });
    },
    async remove(id: string) {
      await db.recurring.delete(id);
      await logHistory('recurring', id, 'delete', 'Gasto fixo removido');
    },
  };
}
