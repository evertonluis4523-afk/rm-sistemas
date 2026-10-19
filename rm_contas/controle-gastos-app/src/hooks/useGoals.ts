import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { uid } from '../utils/id';
import type { Goal } from '../models';
import { logHistory } from '../services/historyLogger';

export function useGoals() {
  const goals = useLiveQuery(async () => (await db.goals.toArray()).sort((a, b) => a.createdAt - b.createdAt), []);

  return {
    goals: goals ?? [],
    loading: goals === undefined,
    async create(data: Omit<Goal, 'id' | 'createdAt' | 'updatedAt'>) {
      const now = Date.now();
      const goal: Goal = { ...data, id: uid(), createdAt: now, updatedAt: now };
      await db.goals.add(goal);
      await logHistory('goal', goal.id, 'create', `Meta criada: ${goal.name}`);
      return goal;
    },
    async update(id: string, patch: Partial<Goal>) {
      await db.goals.update(id, { ...patch, updatedAt: Date.now() });
      await logHistory('goal', id, 'update', 'Meta atualizada');
    },
    async contribute(id: string, amount: number) {
      const goal = await db.goals.get(id);
      if (!goal) return;
      await db.goals.update(id, { currentAmount: goal.currentAmount + amount, updatedAt: Date.now() });
      await logHistory('goal', id, 'update', `Contribuição adicionada à meta ${goal.name}`);
    },
    async remove(id: string) {
      await db.goals.delete(id);
      await logHistory('goal', id, 'delete', 'Meta removida');
    },
  };
}

/** Previsão de conclusão com base no ritmo médio mensal de contribuição desde a criação da meta. */
export function estimateGoalCompletion(goal: Goal): { monthsLeft: number | null; label: string } {
  const monthsElapsed = Math.max(1, (Date.now() - goal.createdAt) / (1000 * 60 * 60 * 24 * 30));
  const monthlyRate = goal.currentAmount / monthsElapsed;
  const remaining = goal.targetAmount - goal.currentAmount;

  if (remaining <= 0) return { monthsLeft: 0, label: 'Meta concluída!' };
  if (monthlyRate <= 0) return { monthsLeft: null, label: 'Adicione contribuições para estimar' };

  const monthsLeft = Math.ceil(remaining / monthlyRate);
  if (monthsLeft <= 1) return { monthsLeft, label: 'Menos de 1 mês' };
  if (monthsLeft < 12) return { monthsLeft, label: `${monthsLeft} meses` };
  return { monthsLeft, label: `${Math.round(monthsLeft / 12)} ano(s)` };
}
