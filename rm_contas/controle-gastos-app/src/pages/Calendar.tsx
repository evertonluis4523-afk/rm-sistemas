import { useMemo, useState } from 'react';
import { startOfMonth, endOfMonth, startOfWeek, endOfWeek, eachDayOfInterval, isSameMonth, isToday, isSameDay } from 'date-fns';
import { MonthTopBar } from '../components/layout/MonthTopBar';
import { EmptyState } from '../components/ui/EmptyState';
import { TransactionRow } from '../components/transaction/TransactionRow';
import { TransactionSheet } from '../components/transaction/TransactionSheet';
import { useMonth } from '../contexts';
import { useTransactions } from '../hooks/useTransactions';
import { useCategoryMap } from '../hooks/useCategories';
import { ymd, WEEKDAY_ABBR } from '../utils/date';
import type { Transaction } from '../models';

export function Calendar() {
  const { month } = useMonth();
  const { transactions } = useTransactions(month);
  const catMap = useCategoryMap();
  const [selected, setSelected] = useState<string>(ymd(new Date()));
  const [editing, setEditing] = useState<Transaction | null>(null);

  const [y, m] = month.split('-').map(Number);
  const monthStart = startOfMonth(new Date(y, m - 1, 1));
  const monthEnd = endOfMonth(monthStart);
  const gridStart = startOfWeek(monthStart);
  const gridEnd = endOfWeek(monthEnd);
  const days = eachDayOfInterval({ start: gridStart, end: gridEnd });

  const byDay = useMemo(() => {
    const map = new Map<string, Transaction[]>();
    transactions.forEach((t) => {
      const list = map.get(t.date) ?? [];
      list.push(t);
      map.set(t.date, list);
    });
    return map;
  }, [transactions]);

  const dayList = byDay.get(selected) ?? [];

  return (
    <>
      <MonthTopBar />
      <main className="view stack">
        <div className="card pad">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4, marginBottom: 6 }}>
            {WEEKDAY_ABBR.map((w) => (
              <div key={w} className="dim center" style={{ fontSize: 10.5, fontWeight: 700 }}>{w}</div>
            ))}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4 }}>
            {days.map((d) => {
              const key = ymd(d);
              const list = byDay.get(key) ?? [];
              const expense = list.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
              const income = list.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0);
              const inMonth = isSameMonth(d, monthStart);
              const isSel = isSameDay(d, new Date(selected + 'T00:00:00'));
              return (
                <button
                  key={key}
                  onClick={() => setSelected(key)}
                  style={{
                    aspectRatio: '1', borderRadius: 12, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2,
                    background: isSel ? 'var(--primary)' : isToday(d) ? 'var(--surface-2)' : 'transparent',
                    opacity: inMonth ? 1 : 0.32,
                    border: isToday(d) && !isSel ? '1.5px solid var(--primary)' : '1.5px solid transparent',
                  }}
                >
                  <span style={{ fontSize: 12.5, fontWeight: 700, color: isSel ? 'var(--on-primary)' : 'var(--text)' }}>{d.getDate()}</span>
                  <div className="row" style={{ gap: 2 }}>
                    {expense > 0 && <span style={{ width: 4, height: 4, borderRadius: '50%', background: isSel ? 'var(--on-primary)' : 'var(--expense)' }} />}
                    {income > 0 && <span style={{ width: 4, height: 4, borderRadius: '50%', background: isSel ? 'var(--on-primary)' : 'var(--income)' }} />}
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', margin: '4px 2px' }}>
          {new Date(selected + 'T00:00:00').toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' })}
        </div>

        {dayList.length === 0 ? (
          <EmptyState icon="event_available" title="Nenhum evento neste dia" subtitle="Não há lançamentos ou contas para esta data." />
        ) : (
          <div className="list">
            {dayList.map((t) => (
              <TransactionRow key={t.id} tx={t} category={catMap.get(t.categoryId)} onClick={() => setEditing(t)} />
            ))}
          </div>
        )}
      </main>
      <TransactionSheet open={!!editing} onClose={() => setEditing(null)} editing={editing} />
    </>
  );
}
