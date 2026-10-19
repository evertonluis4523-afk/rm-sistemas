import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { monthRange, shiftMonth, ymd, daysInMonth } from '../utils/date';
import { computeFinancialHealth, countOverdue, type FinancialHealthResult } from '../services/financialHealth';

async function fetchMonthTx(key: string) {
  const { start, end } = monthRange(key);
  return db.transactions.where('date').between(ymd(start), ymd(end), true, true).toArray();
}

export function useFinancialHealth(monthKeyStr: string): FinancialHealthResult | undefined {
  return useLiveQuery(async () => {
    const todayYmd = ymd(new Date());
    const current = await fetchMonthTx(monthKeyStr);
    const income = current.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const expense = current.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

    const last3 = await Promise.all([1, 2, 3].map((i) => fetchMonthTx(shiftMonth(monthKeyStr, -i))));
    const last3MonthsAvgExpense = last3.reduce((sum, tx) => sum + tx.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0), 0) / 3;

    const daysElapsed = Math.min(new Date().getDate(), daysInMonth(monthKeyStr));
    const dailyAverage = daysElapsed > 0 ? expense / daysElapsed : 0;
    const historicalDailyAverage = last3MonthsAvgExpense / 30;

    const overdueCount = countOverdue(current, todayYmd);

    return computeFinancialHealth({ income, expense, overdueCount, dailyAverage, historicalDailyAverage, last3MonthsAvgExpense });
  }, [monthKeyStr]);
}
