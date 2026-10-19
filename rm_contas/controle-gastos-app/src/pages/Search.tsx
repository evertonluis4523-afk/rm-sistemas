import { useMemo, useState } from 'react';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Icon } from '../components/ui/Icon';
import { Chip } from '../components/ui/Chip';
import { EmptyState } from '../components/ui/EmptyState';
import { TransactionRow } from '../components/transaction/TransactionRow';
import { TransactionSheet } from '../components/transaction/TransactionSheet';
import { useAllTransactions } from '../hooks/useTransactions';
import { useCategoryMap, useCategories } from '../hooks/useCategories';
import { useAccounts } from '../hooks/useAccounts';
import { formatMoney } from '../utils/currency';
import { PAYMENT_METHODS, type Transaction } from '../models';
import { isSameMonth, isSameDay } from '../utils/date';

type Period = 'all' | 'today' | 'week' | 'month' | 'year' | 'custom';

export function Search() {
  const { transactions } = useAllTransactions();
  const catMap = useCategoryMap();
  const { categories } = useCategories();
  const { accounts } = useAccounts();

  const [query, setQuery] = useState('');
  const [period, setPeriod] = useState<Period>('all');
  const [customStart, setCustomStart] = useState('');
  const [customEnd, setCustomEnd] = useState('');
  const [catFilter, setCatFilter] = useState<string | null>(null);
  const [accFilter, setAccFilter] = useState<string | null>(null);
  const [methodFilter, setMethodFilter] = useState<string | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [editing, setEditing] = useState<Transaction | null>(null);

  const results = useMemo(() => {
    const now = new Date();
    const q = query.trim().toLowerCase();

    return transactions
      .filter((t) => {
        if (period === 'today' && !isSameDay(new Date(t.date + 'T00:00:00'), now)) return false;
        if (period === 'week') {
          const d = new Date(t.date + 'T00:00:00');
          const diffDays = Math.abs((now.getTime() - d.getTime()) / 86_400_000);
          if (diffDays > 7) return false;
        }
        if (period === 'month' && !isSameMonth(new Date(t.date + 'T00:00:00'), now)) return false;
        if (period === 'year' && new Date(t.date + 'T00:00:00').getFullYear() !== now.getFullYear()) return false;
        if (period === 'custom' && customStart && customEnd && (t.date < customStart || t.date > customEnd)) return false;
        if (catFilter && t.categoryId !== catFilter) return false;
        if (accFilter && t.accountId !== accFilter) return false;
        if (methodFilter && t.method !== methodFilter) return false;

        if (!q) return true;
        const cat = catMap.get(t.categoryId);
        const acc = accounts.find((a) => a.id === t.accountId);
        const methodLabel = PAYMENT_METHODS.find((m) => m.id === t.method)?.name ?? '';
        const haystack = [
          t.description, t.note, cat?.name, acc?.name, methodLabel, formatMoney(t.amount), t.date,
        ].filter(Boolean).join(' ').toLowerCase();
        return haystack.includes(q);
      })
      .sort((a, b) => b.date.localeCompare(a.date));
  }, [transactions, query, period, customStart, customEnd, catFilter, accFilter, methodFilter, catMap, accounts]);

  const total = results.reduce((s, t) => s + (t.type === 'expense' ? -t.amount : t.amount), 0);

  return (
    <>
      <PageTopBar title="Buscar" back />
      <main className="view stack">
        <div className="input-icon-wrap">
          <span className="msr">search</span>
          <input className="input" placeholder="Valor, categoria, conta, descrição..." value={query} onChange={(e) => setQuery(e.target.value)} autoFocus />
        </div>

        <button className="row-between" style={{ padding: '2px 2px' }} onClick={() => setShowFilters((v) => !v)}>
          <span className="dim" style={{ fontSize: 12.5, fontWeight: 700 }}>Filtros</span>
          <Icon name={showFilters ? 'expand_less' : 'expand_more'} size={18} />
        </button>

        {showFilters && (
          <div className="stack">
            <div className="chips">
              {(['all', 'today', 'week', 'month', 'year', 'custom'] as Period[]).map((p) => (
                <Chip key={p} on={period === p} onClick={() => setPeriod(p)}>
                  {periodLabel(p)}
                </Chip>
              ))}
            </div>
            {period === 'custom' && (
              <div className="row" style={{ gap: 8 }}>
                <input type="date" className="input" value={customStart} onChange={(e) => setCustomStart(e.target.value)} />
                <input type="date" className="input" value={customEnd} onChange={(e) => setCustomEnd(e.target.value)} />
              </div>
            )}
            <div className="chips">
              <Chip on={!catFilter} onClick={() => setCatFilter(null)}>Todas categorias</Chip>
              {categories.map((c) => (
                <Chip key={c.id} on={catFilter === c.id} onClick={() => setCatFilter(catFilter === c.id ? null : c.id)}>
                  {c.name}
                </Chip>
              ))}
            </div>
            {accounts.length > 0 && (
              <div className="chips">
                <Chip on={!accFilter} onClick={() => setAccFilter(null)}>Todas contas</Chip>
                {accounts.map((a) => (
                  <Chip key={a.id} on={accFilter === a.id} onClick={() => setAccFilter(accFilter === a.id ? null : a.id)}>
                    {a.name}
                  </Chip>
                ))}
              </div>
            )}
            <div className="chips">
              <Chip on={!methodFilter} onClick={() => setMethodFilter(null)}>Todos pagamentos</Chip>
              {PAYMENT_METHODS.map((m) => (
                <Chip key={m.id} on={methodFilter === m.id} onClick={() => setMethodFilter(methodFilter === m.id ? null : m.id)}>
                  {m.name}
                </Chip>
              ))}
            </div>
          </div>
        )}

        <div className="row-between" style={{ padding: '6px 2px' }}>
          <span className="dim" style={{ fontSize: 12.5 }}>{results.length} resultado(s)</span>
          <span className="mono" style={{ fontWeight: 700, color: total >= 0 ? 'var(--income)' : 'var(--expense)' }}>{formatMoney(total)}</span>
        </div>

        {results.length === 0 ? (
          <EmptyState icon="search_off" title="Nada encontrado" subtitle="Tente ajustar sua busca ou filtros." />
        ) : (
          <div className="list">
            {results.slice(0, 100).map((t) => (
              <TransactionRow key={t.id} tx={t} category={catMap.get(t.categoryId)} onClick={() => setEditing(t)} />
            ))}
          </div>
        )}
      </main>
      <TransactionSheet open={!!editing} onClose={() => setEditing(null)} editing={editing} />
    </>
  );
}

function periodLabel(p: Period): string {
  return { all: 'Tudo', today: 'Hoje', week: 'Semana', month: 'Mês', year: 'Ano', custom: 'Personalizado' }[p];
}
