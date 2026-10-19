import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { monthRange, shiftMonth, monthAbbrev, ymd } from '../utils/date';
import type { Transaction } from '../models';

export interface CategorySlice {
  catId: string;
  amount: number;
}

export interface MonthPoint {
  key: string;
  label: string;
  income: number;
  expense: number;
}

export interface DashboardData {
  transactions: Transaction[];
  income: number;
  expense: number;
  balance: number;
  savings: number;
  savingsRate: number;
  biggestExpense: Transaction | null;
  byCategory: CategorySlice[];
  topCategory: CategorySlice | null;
  upcomingBills: Transaction[];
  overdueBills: Transaction[];
  recent: Transaction[];
  monthlySeries: MonthPoint[];
  dailyTimeline: { day: number; cumulative: number }[];
}

async function fetchMonthTx(key: string): Promise<Transaction[]> {
  const { start, end } = monthRange(key);
  const startYmd = ymd(start);
  const endYmd = ymd(end);
  return db.transactions.where('date').between(startYmd, endYmd, true, true).toArray();
}

export function useDashboard(monthKeyStr: string): DashboardData | undefined {
  return useLiveQuery(async () => {
    const todayYmd = ymd(new Date());
    const current = await fetchMonthTx(monthKeyStr);

    const income = current.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const expense = current.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
    const balance = income - expense;
    const savings = Math.max(0, balance);
    const savingsRate = income > 0 ? savings / income : 0;

    const expenses = current.filter((t) => t.type === 'expense');
    const biggestExpense = expenses.length ? expenses.reduce((a, b) => (b.amount > a.amount ? b : a)) : null;

    const catMap = new Map<string, number>();
    expenses.forEach((t) => catMap.set(t.categoryId, (catMap.get(t.categoryId) || 0) + t.amount));
    const byCategory: CategorySlice[] = [...catMap.entries()].map(([catId, amount]) => ({ catId, amount })).sort((a, b) => b.amount - a.amount);
    const topCategory = byCategory[0] ?? null;

    const upcomingBills = current
      .filter((t) => t.type === 'expense' && !t.paid && t.date >= todayYmd)
      .sort((a, b) => a.date.localeCompare(b.date))
      .slice(0, 6);

    const overdueBills = current.filter((t) => t.type === 'expense' && !t.paid && t.date < todayYmd).sort((a, b) => a.date.localeCompare(b.date));

    const recent = [...current].sort((a, b) => b.date.localeCompare(a.date) || b.createdAt - a.createdAt).slice(0, 6);

    const monthlySeries: MonthPoint[] = [];
    for (let i = 5; i >= 0; i--) {
      const key = shiftMonth(monthKeyStr, -i);
      const tx = key === monthKeyStr ? current : await fetchMonthTx(key);
      monthlySeries.push({
        key,
        label: monthAbbrev(key),
        income: tx.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
        expense: tx.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
      });
    }

    const dailyMap = new Map<number, number>();
    expenses.forEach((t) => {
      const day = Number(t.date.slice(8, 10));
      dailyMap.set(day, (dailyMap.get(day) || 0) + t.amount);
    });
    const sortedDays = [...dailyMap.keys()].sort((a, b) => a - b);
    let cumulative = 0;
    const dailyTimeline = sortedDays.map((day) => {
      cumulative += dailyMap.get(day) || 0;
      return { day, cumulative };
    });

    const result: DashboardData = {
      transactions: current,
      income,
      expense,
      balance,
      savings,
      savingsRate,
      biggestExpense,
      byCategory,
      topCategory,
      upcomingBills,
      overdueBills,
      recent,
      monthlySeries,
      dailyTimeline,
    };
    return result;
  }, [monthKeyStr]);
}
