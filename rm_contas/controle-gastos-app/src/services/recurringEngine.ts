import { db } from '../database/db';
import { uid } from '../utils/id';
import { monthKey, daysInMonth, ymd } from '../utils/date';

/** Materializa os lançamentos fixos (recorrentes) do mês atual, se ainda não existirem. */
export async function materializeRecurring(): Promise<void> {
  const now = new Date();
  const key = monthKey(now);
  const lastDay = daysInMonth(key);
  const todayYmd = ymd(now);

  const all = await db.recurring.toArray();
  const active = all.filter((r) => r.active);

  for (const r of active) {
    const existing = await db.transactions.where('recurringId').equals(r.id).toArray();
    const alreadyThisMonth = existing.some((t) => t.date.slice(0, 7) === key);
    if (alreadyThisMonth) continue;

    const day = Math.min(r.day, lastDay);
    const date = `${key}-${String(day).padStart(2, '0')}`;
    const nowMs = Date.now();
    await db.transactions.add({
      id: uid(),
      type: r.type,
      amount: r.amount,
      categoryId: r.categoryId,
      accountId: r.accountId,
      cardId: r.cardId,
      method: r.method,
      date,
      description: r.description,
      recurringId: r.id,
      paid: date <= todayYmd,
      createdAt: nowMs,
      updatedAt: nowMs,
    });
  }
}
