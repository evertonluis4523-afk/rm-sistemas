import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import { monthKey, shiftMonth } from '../utils/date';

interface MonthContextValue {
  month: string;
  setMonth: (key: string) => void;
  next: () => void;
  prev: () => void;
  goToday: () => void;
  isCurrent: boolean;
}

const MonthContext = createContext<MonthContextValue | null>(null);

export function MonthProvider({ children }: { children: ReactNode }) {
  const [month, setMonth] = useState(() => monthKey(new Date()));

  const value = useMemo<MonthContextValue>(
    () => ({
      month,
      setMonth,
      next: () => setMonth((m) => shiftMonth(m, 1)),
      prev: () => setMonth((m) => shiftMonth(m, -1)),
      goToday: () => setMonth(monthKey(new Date())),
      isCurrent: month === monthKey(new Date()),
    }),
    [month]
  );

  return <MonthContext.Provider value={value}>{children}</MonthContext.Provider>;
}

export function useMonth(): MonthContextValue {
  const ctx = useContext(MonthContext);
  if (!ctx) throw new Error('useMonth deve ser usado dentro de MonthProvider');
  return ctx;
}
