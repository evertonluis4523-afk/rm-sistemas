import { useMemo } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { MonthTopBar } from '../components/layout/MonthTopBar';
import { Icon } from '../components/ui/Icon';
import { EmptyState } from '../components/ui/EmptyState';
import { TransactionRow } from '../components/transaction/TransactionRow';
import { TransactionSheet } from '../components/transaction/TransactionSheet';
import { useMonth } from '../contexts';
import { useTransactions } from '../hooks/useTransactions';
import { useCategoryMap } from '../hooks/useCategories';
import { useAccountNameMap } from '../hooks/useAccounts';
import { dayHeading } from '../utils/date';
import { formatMoney } from '../utils/currency';
import type { Transaction } from '../models';

export function Transactions() {
  const navigate = useNavigate();
  const { month } = useMonth();
  const { transactions } = useTransactions(month);
  const catMap = useCategoryMap();
  const accMap = useAccountNameMap();
  const [params, setParams] = useSearchParams();

  const editingId = params.get('edit');
  const editingTx = useMemo(() => transactions.find((t) => t.id === editingId) ?? null, [transactions, editingId]);

  const income = transactions.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const expense = transactions.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

  const grouped = useMemo(() => {
    const days = new Map<string, Transaction[]>();
    transactions.forEach((t) => {
      const list = days.get(t.date) ?? [];
      list.push(t);
      days.set(t.date, list);
    });
    return [...days.entries()];
  }, [transactions]);

  function closeSheet() {
    if (editingId) {
      params.delete('edit');
      setParams(params, { replace: true });
    }
  }

  return (
    <>
      <MonthTopBar
        rightAction={
          <button className="btn icon-only ghost" onClick={() => navigate('/busca')} aria-label="Buscar">
            <Icon name="search" />
          </button>
        }
      />
      <main className="view stack">
        {/* Cartão duplo: saldo do mês | balanço (estilo Mobills) */}
        <div className="card pad" style={{ display: 'flex' }}>
          <div style={{ flex: 1, display: 'flex', gap: 10, alignItems: 'center' }}>
            <Icon name="arrow_upward" style={{ color: 'var(--income)' }} />
            <div>
              <div className="dim" style={{ fontSize: 12 }}>Receitas</div>
              <div className="mono" style={{ fontWeight: 700, color: 'var(--income)' }}>{formatMoney(income)}</div>
            </div>
          </div>
          <div style={{ width: 1, background: 'var(--line)' }} />
          <div style={{ flex: 1, display: 'flex', gap: 10, alignItems: 'center', paddingLeft: 14 }}>
            <Icon name="arrow_downward" style={{ color: 'var(--expense)' }} />
            <div>
              <div className="dim" style={{ fontSize: 12 }}>Despesas</div>
              <div className="mono" style={{ fontWeight: 700, color: 'var(--expense)' }}>{formatMoney(expense)}</div>
            </div>
          </div>
        </div>

        {transactions.length === 0 ? (
          <EmptyState icon="receipt_long" title="Nenhum lançamento neste mês" subtitle="Toque no + para registrar um gasto ou receita." />
        ) : (
          grouped.map(([date, list]) => (
            <div key={date}>
              <div className="row-between" style={{ padding: '12px 4px 7px', fontSize: 12, fontWeight: 700, color: 'var(--text-3)' }}>
                <span>{dayHeading(date)}</span>
                <span className="mono">{formatMoney(list.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0))}</span>
              </div>
              <div className="list">
                {list.map((t) => (
                  <TransactionRow
                    key={t.id}
                    tx={t}
                    category={catMap.get(t.categoryId)}
                    accountName={t.accountId ? accMap.get(t.accountId) : undefined}
                    onClick={() => setParams({ edit: t.id })}
                  />
                ))}
              </div>
            </div>
          ))
        )}
      </main>
      <TransactionSheet open={!!editingTx} onClose={closeSheet} editing={editingTx} />
    </>
  );
}
