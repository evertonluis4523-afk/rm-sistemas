import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { uid } from '../utils/id';
import type { Card } from '../models';
import { logHistory } from '../services/historyLogger';
import { monthRange } from '../utils/date';

export function useCards(includeArchived = false) {
  const cards = useLiveQuery(async () => {
    const all = (await db.cards.toArray()).sort((a, b) => a.createdAt - b.createdAt);
    return includeArchived ? all : all.filter((c) => !c.archived);
  }, [includeArchived]);

  return {
    cards: cards ?? [],
    loading: cards === undefined,
    async create(data: Omit<Card, 'id' | 'createdAt' | 'updatedAt' | 'archived'>) {
      const now = Date.now();
      const card: Card = { ...data, id: uid(), archived: false, createdAt: now, updatedAt: now };
      await db.cards.add(card);
      await logHistory('card', card.id, 'create', `Cartão criado: ${card.name}`);
      return card;
    },
    async update(id: string, patch: Partial<Card>) {
      await db.cards.update(id, { ...patch, updatedAt: Date.now() });
      await logHistory('card', id, 'update', 'Cartão atualizado');
    },
    async archive(id: string) {
      await db.cards.update(id, { archived: true, updatedAt: Date.now() });
      await logHistory('card', id, 'delete', 'Cartão arquivado');
    },
    async remove(id: string) {
      await db.cards.delete(id);
      await logHistory('card', id, 'delete', 'Cartão removido');
    },
  };
}

/** Fatura do cartão no mês (soma dos lançamentos de crédito vinculados). */
export function useCardInvoice(cardId: string, monthKeyStr: string) {
  return useLiveQuery(async () => {
    const { start, end } = monthRange(monthKeyStr);
    const startYmd = start.toISOString().slice(0, 10);
    const endYmd = end.toISOString().slice(0, 10);
    const txs = await db.transactions.where('cardId').equals(cardId).toArray();
    return txs.filter((t) => t.date >= startYmd && t.date <= endYmd).reduce((sum, t) => sum + t.amount, 0);
  }, [cardId, monthKeyStr]) ?? 0;
}
