import { useNavigate } from 'react-router-dom';
import { endOfMonth, differenceInCalendarDays } from 'date-fns';
import { MonthTopBar } from '../components/layout/MonthTopBar';
import { Card } from '../components/ui/Card';
import { Icon } from '../components/ui/Icon';
import { ProgressBar } from '../components/ui/ProgressBar';
import { ScoreRing } from '../components/ui/ScoreRing';
import { EmptyState } from '../components/ui/EmptyState';
import { SkeletonCard } from '../components/ui/Skeleton';
import { TransactionRow } from '../components/transaction/TransactionRow';
import { DonutChart } from '../components/charts/DonutChart';
import { LineChart } from '../components/charts/LineChart';
import { useMonth } from '../contexts';
import { useDashboard } from '../hooks/useDashboard';
import { useFinancialHealth } from '../hooks/useFinancialHealth';
import { useInsights } from '../hooks/useInsights';
import { useCategoryMap } from '../hooks/useCategories';
import { useAccountBalances } from '../hooks/useAccountBalances';
import { useAccountNameMap } from '../hooks/useAccounts';
import { useBudgets } from '../hooks/useBudgets';
import { formatMoney } from '../utils/currency';

const badge = (bg: string): React.CSSProperties => ({
  width: 42,
  height: 42,
  borderRadius: 14,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  flexShrink: 0,
  background: bg,
});

export function Dashboard() {
  const navigate = useNavigate();
  const { month } = useMonth();
  const data = useDashboard(month);
  const health = useFinancialHealth(month);
  const insights = useInsights(month);
  const catMap = useCategoryMap();
  const { total: totalBalance } = useAccountBalances();
  const accMap = useAccountNameMap();
  const { budgets } = useBudgets();
  const generalBudget = budgets.find((b) => b.id === 'general');

  if (!data) {
    return (
      <>
        <MonthTopBar />
        <main className="view stack">
          <SkeletonCard />
          <SkeletonCard />
        </main>
      </>
    );
  }

  const now = new Date();
  const daysLeft = Math.max(1, differenceInCalendarDays(endOfMonth(now), now) + 1);
  const canSpendToday = generalBudget
    ? Math.max(0, (generalBudget.amount - data.expense) / daysLeft)
    : Math.max(0, (data.income - data.expense) / daysLeft);

  const tip = health ? [...health.factors].sort((a, b) => a.value - b.value)[0]?.detail : '';

  const budgetPct = generalBudget ? Math.min(100, Math.round((data.expense / generalBudget.amount) * 100)) : 0;
  const budgetTone = !generalBudget ? 'primary' : data.expense > generalBudget.amount ? 'over' : data.expense > generalBudget.amount * 0.85 ? 'warn' : 'primary';

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
        {/* Saldo do mês */}
        <Card elevated>
          <div className="dim" style={{ fontSize: 13, fontWeight: 600 }}>Saldo do mês</div>
          <div className="mono" style={{ fontSize: 30, fontWeight: 800, margin: '4px 0 16px' }}>{formatMoney(totalBalance)}</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            <div className="row" style={{ gap: 11 }}>
              <span style={badge('rgba(46,204,113,0.15)')}><Icon name="arrow_upward" style={{ color: 'var(--income)' }} /></span>
              <div style={{ minWidth: 0 }}>
                <div className="dim" style={{ fontSize: 12 }}>Receitas</div>
                <strong className="mono" style={{ color: 'var(--income)', fontSize: 15 }}>{formatMoney(data.income)}</strong>
              </div>
            </div>
            <div className="row" style={{ gap: 11 }}>
              <span style={badge('rgba(255,92,92,0.15)')}><Icon name="arrow_downward" style={{ color: 'var(--expense)' }} /></span>
              <div style={{ minWidth: 0 }}>
                <div className="dim" style={{ fontSize: 12 }}>Despesas</div>
                <strong className="mono" style={{ color: 'var(--expense)', fontSize: 15 }}>{formatMoney(data.expense)}</strong>
              </div>
            </div>
          </div>
        </Card>

        {/* Saúde financeira */}
        {health && (
          <Card>
            <div className="row" style={{ gap: 18 }}>
              <ScoreRing score={health.score} color={health.color} label={health.label} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <h2 style={{ fontSize: 16, fontWeight: 700 }}>Saúde financeira</h2>
                <p className="dim" style={{ fontSize: 13, margin: '6px 0 12px' }}>{tip}</p>
                <div className="row-between">
                  <span className="dim" style={{ fontSize: 13 }}>Pode gastar hoje</span>
                  <strong className="mono" style={{ color: 'var(--primary-2)' }}>{formatMoney(canSpendToday)}</strong>
                </div>
              </div>
            </div>
          </Card>
        )}

        {/* Meta / planejamento do mês */}
        {generalBudget && (
          <Card>
            <div className="row-between" style={{ marginBottom: 10 }}>
              <h2 style={{ fontSize: 16, fontWeight: 700 }}>Planejamento do mês</h2>
              <span className="dim" style={{ fontSize: 13 }}>{formatMoney(data.expense)} / {formatMoney(generalBudget.amount)}</span>
            </div>
            <ProgressBar value={budgetPct} tone={budgetTone} />
          </Card>
        )}

        {/* Maior gasto / maior categoria */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <Card>
            <div className="dim" style={{ fontSize: 12 }}>Maior gasto</div>
            <strong className="mono" style={{ fontSize: 16, display: 'block', margin: '3px 0' }}>{data.biggestExpense ? formatMoney(data.biggestExpense.amount) : '—'}</strong>
            <div className="dim" style={{ fontSize: 11.5, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {data.biggestExpense ? data.biggestExpense.description || catMap.get(data.biggestExpense.categoryId)?.name : 'Sem despesas'}
            </div>
          </Card>
          <Card>
            <div className="dim" style={{ fontSize: 12 }}>Maior categoria</div>
            <strong style={{ fontSize: 16, display: 'block', margin: '3px 0' }}>{data.topCategory ? catMap.get(data.topCategory.catId)?.name ?? '—' : '—'}</strong>
            <div className="dim mono" style={{ fontSize: 11.5 }}>{data.topCategory ? formatMoney(data.topCategory.amount) : 'Sem despesas'}</div>
          </Card>
        </div>

        {/* Insights */}
        {insights.length > 0 && (
          <Card>
            <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 6 }}>Insights</h2>
            {insights.slice(0, 3).map((i) => (
              <div className="list-item" key={i.id} style={{ padding: '10px 0' }}>
                <Icon name={i.icon} style={{ color: i.kind === 'negative' || i.kind === 'alert' ? 'var(--expense)' : i.kind === 'positive' ? 'var(--income)' : 'var(--primary)' }} />
                <span style={{ fontSize: 13 }}>{i.text}</span>
              </div>
            ))}
          </Card>
        )}

        {/* Gasto acumulado no mês */}
        {data.dailyTimeline.length > 1 && (
          <Card>
            <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 8 }}>Gasto acumulado no mês</h2>
            <LineChart labels={data.dailyTimeline.map((d) => d.day)} values={data.dailyTimeline.map((d) => d.cumulative)} />
          </Card>
        )}

        {/* Por categoria */}
        {data.byCategory.length > 0 && (
          <Card>
            <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 10 }}>Por categoria</h2>
            <DonutChart slices={data.byCategory.slice(0, 6).map((c) => ({ label: catMap.get(c.catId)?.name ?? '—', value: c.amount, color: catMap.get(c.catId)?.color ?? '#8E95A2' }))} />
          </Card>
        )}

        {/* Próximas contas */}
        {data.upcomingBills.length > 0 && (
          <Card pad={false} style={{ padding: '16px 16px 6px' }}>
            <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Próximas contas</h2>
            {data.upcomingBills.map((t) => (
              <TransactionRow key={t.id} tx={t} category={catMap.get(t.categoryId)} accountName={t.accountId ? accMap.get(t.accountId) : undefined} />
            ))}
          </Card>
        )}

        {/* Últimos lançamentos */}
        <Card pad={false} style={{ padding: '16px 16px 6px' }}>
          <div className="row-between" style={{ marginBottom: 4 }}>
            <h2 style={{ fontSize: 16, fontWeight: 700 }}>Últimos lançamentos</h2>
            <button className="dim" style={{ fontSize: 13, fontWeight: 600 }} onClick={() => navigate('/lancamentos')}>Ver todos</button>
          </div>
          {data.recent.length === 0 ? (
            <EmptyState icon="receipt_long" title="Nenhum lançamento" subtitle="Toque no + para registrar." />
          ) : (
            data.recent.map((t) => (
              <TransactionRow key={t.id} tx={t} category={catMap.get(t.categoryId)} accountName={t.accountId ? accMap.get(t.accountId) : undefined} onClick={() => navigate(`/lancamentos?edit=${t.id}`)} />
            ))
          )}
        </Card>
      </main>
    </>
  );
}
