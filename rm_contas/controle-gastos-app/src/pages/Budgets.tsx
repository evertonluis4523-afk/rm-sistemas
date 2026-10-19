import { useState } from 'react';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Icon } from '../components/ui/Icon';
import { ProgressBar } from '../components/ui/ProgressBar';
import { useMonth } from '../contexts';
import { useTransactions } from '../hooks/useTransactions';
import { useCategories } from '../hooks/useCategories';
import { useBudgets } from '../hooks/useBudgets';
import { formatMoney } from '../utils/currency';
import { BudgetInputSheet } from '../components/forms/BudgetInputSheet';

export function Budgets() {
  const { month } = useMonth();
  const { transactions } = useTransactions(month);
  const { categories } = useCategories('expense');
  const { budgets } = useBudgets();
  const [editingGeneral, setEditingGeneral] = useState(false);
  const [editingCat, setEditingCat] = useState<string | null>(null);

  const generalBudget = budgets.find((b) => b.id === 'general');
  const expense = transactions.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
  const generalPct = generalBudget ? Math.min(100, Math.round((expense / generalBudget.amount) * 100)) : 0;
  const generalTone = !generalBudget ? 'primary' : expense > generalBudget.amount ? 'over' : expense > generalBudget.amount * 0.85 ? 'warn' : 'primary';

  return (
    <>
      <PageTopBar title="Orçamentos" back />
      <main className="view stack">
        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)' }}>Orçamento geral do mês</div>
        <div className="card pad" onClick={() => setEditingGeneral(true)} style={{ cursor: 'pointer' }}>
          <div className="row-between">
            <span className="dim" style={{ fontSize: 12.5, fontWeight: 600 }}>Limite mensal</span>
            <span style={{ color: 'var(--primary)', fontWeight: 700, fontSize: 12.5 }}>Editar</span>
          </div>
          <div className="mono" style={{ fontSize: 24, fontWeight: 800, marginTop: 2 }}>{generalBudget ? formatMoney(generalBudget.amount) : 'Não definido'}</div>
          {generalBudget && (
            <div style={{ marginTop: 12 }}>
              <ProgressBar value={generalPct} tone={generalTone} />
              <div className="row-between" style={{ marginTop: 6, fontSize: 12 }}>
                <span className="dim">Gasto {formatMoney(expense)} · {generalPct}%</span>
                <span style={{ color: expense > generalBudget.amount ? 'var(--expense)' : 'var(--income)' }}>
                  {expense > generalBudget.amount ? `Excedeu ${formatMoney(expense - generalBudget.amount)}` : `Resta ${formatMoney(generalBudget.amount - expense)}`}
                </span>
              </div>
            </div>
          )}
        </div>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', marginTop: 8 }}>Limites por categoria</div>
        <div className="list">
          {categories.map((c) => {
            const gasto = transactions.filter((t) => t.type === 'expense' && t.categoryId === c.id).reduce((s, t) => s + t.amount, 0);
            const budget = budgets.find((b) => b.id === c.id);
            const pct = budget ? Math.min(100, Math.round((gasto / budget.amount) * 100)) : 0;
            const tone = !budget ? 'primary' : gasto > budget.amount ? 'over' : gasto > budget.amount * 0.85 ? 'warn' : 'primary';
            return (
              <div key={c.id} className="list-item" style={{ flexDirection: 'column', alignItems: 'stretch' }} onClick={() => setEditingCat(c.id)}>
                <div className="row-between">
                  <div className="row" style={{ gap: 10 }}>
                    <span className="avatar" style={{ background: c.color + '26', color: c.color, width: 32, height: 32 }}>
                      <Icon name={c.icon} size={16} />
                    </span>
                    <span style={{ fontWeight: 600, fontSize: 14 }}>{c.name}</span>
                  </div>
                  <span className="mono" style={{ fontSize: 12.5 }}>
                    {budget ? <><b>{formatMoney(gasto)}</b> / {formatMoney(budget.amount)}</> : <span style={{ color: 'var(--primary)', fontWeight: 700 }}>Definir limite</span>}
                  </span>
                </div>
                {budget && <div style={{ marginTop: 8 }}><ProgressBar value={pct} tone={tone} /></div>}
              </div>
            );
          })}
        </div>
      </main>

      <BudgetInputSheet
        open={editingGeneral}
        title="Orçamento geral"
        currentAmount={generalBudget?.amount}
        onClose={() => setEditingGeneral(false)}
        target="general"
      />
      <BudgetInputSheet
        open={!!editingCat}
        title={editingCat ? `Limite: ${categories.find((c) => c.id === editingCat)?.name}` : ''}
        currentAmount={editingCat ? budgets.find((b) => b.id === editingCat)?.amount : undefined}
        onClose={() => setEditingCat(null)}
        target={editingCat ?? undefined}
      />
    </>
  );
}
