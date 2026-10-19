import { formatMoney } from '../utils/currency';

export type InsightKind = 'positive' | 'negative' | 'neutral' | 'alert';

export interface Insight {
  id: string;
  icon: string;
  kind: InsightKind;
  text: string;
}

export interface InsightsInput {
  income: number;
  expense: number;
  prevExpense: number;
  budget?: number;
  daysElapsed: number;
  daysInMonth: number;
  byCategory: { catId: string; catName: string; amount: number }[];
  byCategoryPrev: { catId: string; amount: number }[];
}

/**
 * Motor de insights local (sem chamadas externas): compara o mês atual com o anterior,
 * projeta o fechamento do mês por regressão linear simples sobre o ritmo diário de gastos,
 * e gera recomendações de economia com base nas maiores categorias.
 */
export function generateInsights(input: InsightsInput): Insight[] {
  const { income, expense, prevExpense, budget, daysElapsed, daysInMonth, byCategory, byCategoryPrev } = input;
  const insights: Insight[] = [];

  // Comparação com mês anterior
  if (prevExpense > 0) {
    const diff = expense - prevExpense;
    const pct = Math.round((Math.abs(diff) / prevExpense) * 100);
    if (diff < 0) {
      insights.push({ id: 'cmp', icon: 'trending_down', kind: 'positive', text: `Você gastou ${pct}% a menos que no mês anterior. Continue assim!` });
    } else if (diff > 0) {
      insights.push({ id: 'cmp', icon: 'trending_up', kind: 'negative', text: `Seus gastos subiram ${pct}% em relação ao mês anterior.` });
    }
  }

  // Categoria que mais aumentou / diminuiu
  const deltas = byCategory.map((c) => {
    const prev = byCategoryPrev.find((p) => p.catId === c.catId)?.amount ?? 0;
    return { ...c, delta: c.amount - prev, prev };
  });
  const mostIncreased = [...deltas].sort((a, b) => b.delta - a.delta)[0];
  const mostDecreased = [...deltas].sort((a, b) => a.delta - b.delta)[0];
  if (mostIncreased && mostIncreased.delta > 0 && mostIncreased.prev > 0) {
    insights.push({ id: 'up', icon: 'arrow_upward', kind: 'negative', text: `${mostIncreased.catName} foi a categoria que mais aumentou: +${formatMoney(mostIncreased.delta)}.` });
  }
  if (mostDecreased && mostDecreased.delta < 0) {
    insights.push({ id: 'down', icon: 'arrow_downward', kind: 'positive', text: `Você reduziu ${mostDecreased.catName} em ${formatMoney(-mostDecreased.delta)} este mês.` });
  }

  // Quanto pode gastar por dia (restante do orçamento / dias restantes)
  const daysLeft = Math.max(1, daysInMonth - daysElapsed);
  if (budget && budget > 0) {
    const remaining = budget - expense;
    const perDay = remaining / daysLeft;
    if (remaining >= 0) {
      insights.push({ id: 'perday', icon: 'today', kind: perDay < (budget / daysInMonth) * 0.5 ? 'alert' : 'neutral', text: `Você pode gastar até ${formatMoney(Math.max(0, perDay))} por dia até o fim do mês.` });
    } else {
      insights.push({ id: 'perday', icon: 'warning', kind: 'alert', text: `Orçamento do mês já foi ultrapassado em ${formatMoney(-remaining)}.` });
    }
  }

  // Previsão de fechamento do mês (projeção linear pelo ritmo diário)
  if (daysElapsed > 0) {
    const dailyRate = expense / daysElapsed;
    const projected = dailyRate * daysInMonth;
    insights.push({ id: 'forecast', icon: 'query_stats', kind: 'neutral', text: `No ritmo atual, o mês deve fechar com ${formatMoney(projected)} em despesas.` });

    if (budget && projected > budget) {
      insights.push({ id: 'forecast-alert', icon: 'error', kind: 'alert', text: `Nesse ritmo, você vai ultrapassar o orçamento em ${formatMoney(projected - budget)}.` });
    }
  }

  // Sugestão de economia: maior categoria de despesa
  const topCategory = [...byCategory].sort((a, b) => b.amount - a.amount)[0];
  if (topCategory && expense > 0) {
    const share = Math.round((topCategory.amount / expense) * 100);
    if (share >= 30) {
      insights.push({ id: 'suggestion', icon: 'lightbulb', kind: 'neutral', text: `${topCategory.catName} representa ${share}% dos seus gastos. Reduzir 10% aqui pode gerar uma boa economia mensal.` });
    }
  }

  // Saldo do mês
  const balance = income - expense;
  if (income > 0) {
    if (balance >= 0) {
      insights.push({ id: 'balance', icon: 'savings', kind: 'positive', text: `Você está economizando ${Math.round((balance / income) * 100)}% da sua receita este mês.` });
    } else {
      insights.push({ id: 'balance', icon: 'trending_down', kind: 'alert', text: `Suas despesas superaram a receita em ${formatMoney(-balance)} este mês.` });
    }
  }

  return insights;
}
