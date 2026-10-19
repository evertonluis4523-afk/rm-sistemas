import { useState } from 'react';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Card } from '../components/ui/Card';
import { Icon } from '../components/ui/Icon';
import { ProgressBar } from '../components/ui/ProgressBar';
import { EmptyState } from '../components/ui/EmptyState';
import { Button } from '../components/ui/Button';
import { useGoals, estimateGoalCompletion } from '../hooks/useGoals';
import { formatMoney } from '../utils/currency';
import { GoalFormSheet } from '../components/forms/GoalFormSheet';
import { ContributeSheet } from '../components/forms/ContributeSheet';
import type { Goal } from '../models';

export function Goals() {
  const { goals } = useGoals();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Goal | null>(null);
  const [contributing, setContributing] = useState<Goal | null>(null);

  return (
    <>
      <PageTopBar
        title="Metas"
        rightAction={
          <button className="btn icon-only ghost" onClick={() => { setEditing(null); setOpen(true); }} aria-label="Nova meta">
            <Icon name="add" />
          </button>
        }
      />
      <main className="view stack">
        {goals.length === 0 ? (
          <EmptyState icon="flag" title="Nenhuma meta criada" subtitle="Crie metas para viagem, casa, carro, reserva de emergência ou o que quiser." />
        ) : (
          goals.map((g) => {
            const pct = g.targetAmount > 0 ? Math.min(100, Math.round((g.currentAmount / g.targetAmount) * 100)) : 0;
            const forecast = estimateGoalCompletion(g);
            return (
              <Card key={g.id} elevated>
                <div className="row-between" onClick={() => { setEditing(g); setOpen(true); }} style={{ cursor: 'pointer' }}>
                  <div className="row" style={{ gap: 12 }}>
                    <span className="avatar" style={{ background: g.color + '26', color: g.color, width: 46, height: 46 }}>
                      <Icon name={g.icon} size={22} />
                    </span>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: 15 }}>{g.name}</div>
                      <div className="dim" style={{ fontSize: 12 }}>{forecast.label}</div>
                    </div>
                  </div>
                  <div className="mono" style={{ fontWeight: 800, fontSize: 17, color: g.color }}>{pct}%</div>
                </div>
                <div style={{ marginTop: 14 }}>
                  <ProgressBar value={pct} />
                  <div className="row-between" style={{ marginTop: 7, fontSize: 12 }}>
                    <span className="mono dim">{formatMoney(g.currentAmount)}</span>
                    <span className="mono dim">{formatMoney(g.targetAmount)}</span>
                  </div>
                </div>
                <Button variant="secondary" size="sm" icon="add" onClick={() => setContributing(g)} style={{ marginTop: 12 }}>
                  Adicionar valor
                </Button>
              </Card>
            );
          })
        )}
      </main>
      <GoalFormSheet open={open} onClose={() => setOpen(false)} editing={editing} />
      <ContributeSheet goal={contributing} onClose={() => setContributing(null)} />
    </>
  );
}
