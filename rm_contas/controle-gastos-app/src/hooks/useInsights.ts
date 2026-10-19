import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { monthRange, shiftMonth, ymd, daysInMonth } from '../utils/date';
import { generateInsights, type Insight } from '../services/insights';

async function fetchMonthTx(key: string) {
  const { start, end } = monthRange(key);
  return db.transactions.where('date').between(ymd(start), ymd(end), true, true).toArray();
}

export function useInsights(monthKeyStr: string): Insight[] {
  const insights = useLiveQuery(async () => {
    const [current, previous, categories, generalBudget] = await Promise.all([
      fetchMonthTx(monthKeyStr),
      fetchMonthTx(shiftMonth(monthKeyStr, -1)),
      db.categories.toArray(),
      db.budgets.get('general'),
    ]);

    const catName = new Map(categories.map((c) => [c.id, c.name]));
    const income = current.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const expense = current.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
    const prevExpense = previous.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

    const byCatMap = new Map<string, number>();
    current.filter((t) => t.type === 'expense').forEach((t) => byCatMap.set(t.categoryId, (byCatMap.get(t.categoryId) || 0) + t.amount));
    const byCategory = [...byCatMap.entries()].map(([catId, amount]) => ({ catId, catName: catName.get(catId) || '—', amount }));

    const byCatPrevMap = new Map<string, number>();
    previous.filter((t) => t.type === 'expense').forEach((t) => byCatPrevMap.set(t.categoryId, (byCatPrevMap.get(t.categoryId) || 0) + t.amount));
    const byCategoryPrev = [...byCatPrevMap.entries()].map(([catId, amount]) => ({ catId, amount }));

    const daysElapsed = Math.min(new Date().getDate(), daysInMonth(monthKeyStr));

    return generateInsights({
      income,
      expense,
      prevExpense,
      budget: generalBudget?.amount,
      daysElapsed,
      daysInMonth: daysInMonth(monthKeyStr),
      byCategory,
      byCategoryPrev,
    });
  }, [monthKeyStr]);

  return insights ?? [];
}
