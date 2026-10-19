import type { Transaction } from '../models';

export type HealthLabel = 'Excelente' | 'Boa' | 'Atenção' | 'Risco' | 'Crítica';

export interface FinancialHealthResult {
  score: number; // 0-100
  label: HealthLabel;
  color: string;
  factors: { name: string; value: number; weight: number; detail: string }[];
}

/**
 * Algoritmo próprio de Saúde Financeira (0-100).
 *
 * Pondera cinco fatores, cada um normalizado para 0-100 antes de aplicar o peso:
 *  - Taxa de economia do mês (peso 30): quanto da receita sobra após despesas.
 *  - Equilíbrio receita/despesa (peso 20): despesas não devem superar a receita.
 *  - Contas vencidas (peso 20): penaliza lançamentos futuros não pagos e já vencidos.
 *  - Consistência da média diária (peso 15): desvio do gasto diário em relação à média do histórico.
 *  - Tendência histórica (peso 15): comparação do gasto deste mês com a média dos últimos 3 meses.
 */
export function computeFinancialHealth(params: {
  income: number;
  expense: number;
  overdueCount: number;
  dailyAverage: number;
  historicalDailyAverage: number;
  last3MonthsAvgExpense: number;
}): FinancialHealthResult {
  const { income, expense, overdueCount, dailyAverage, historicalDailyAverage, last3MonthsAvgExpense } = params;

  // 1. Taxa de economia
  const savingsRate = income > 0 ? Math.max(-1, (income - expense) / income) : expense > 0 ? -1 : 0;
  const savingsScore = clamp((savingsRate + 0.2) / 0.5, 0, 1) * 100; // 0% de economia ~ 40pts; 30%+ ~ 100pts

  // 2. Equilíbrio receita/despesa
  const ratio = income > 0 ? expense / income : expense > 0 ? 2 : 0;
  const balanceScore = clamp(1 - (ratio - 0.6) / 0.8, 0, 1) * 100;

  // 3. Contas vencidas
  const overdueScore = clamp(1 - overdueCount / 5, 0, 1) * 100;

  // 4. Consistência do gasto diário
  const dailyDeviation = historicalDailyAverage > 0 ? Math.abs(dailyAverage - historicalDailyAverage) / historicalDailyAverage : 0;
  const consistencyScore = clamp(1 - dailyDeviation, 0, 1) * 100;

  // 5. Tendência histórica (este mês vs média dos últimos 3)
  const trendRatio = last3MonthsAvgExpense > 0 ? expense / last3MonthsAvgExpense : 1;
  const trendScore = clamp(1 - (trendRatio - 1), 0, 1) * 100;

  const factors = [
    { name: 'Taxa de economia', value: savingsScore, weight: 0.3, detail: `${Math.round(savingsRate * 100)}% da receita economizada` },
    { name: 'Equilíbrio receita/despesa', value: balanceScore, weight: 0.2, detail: income > 0 ? `Gastou ${Math.round(ratio * 100)}% da receita` : 'Sem receita registrada' },
    { name: 'Contas em dia', value: overdueScore, weight: 0.2, detail: overdueCount === 0 ? 'Nenhuma conta vencida' : `${overdueCount} conta(s) vencida(s)` },
    { name: 'Consistência de gastos', value: consistencyScore, weight: 0.15, detail: 'Comparado à média diária histórica' },
    { name: 'Tendência do mês', value: trendScore, weight: 0.15, detail: trendRatio <= 1 ? 'Gastando menos que a média' : 'Gastando mais que a média' },
  ];

  const score = Math.round(factors.reduce((sum, f) => sum + f.value * f.weight, 0));
  const { label, color } = classify(score);

  return { score, label, color, factors };
}

function classify(score: number): { label: HealthLabel; color: string } {
  if (score >= 85) return { label: 'Excelente', color: '#2ECC71' };
  if (score >= 65) return { label: 'Boa', color: '#8BC34A' };
  if (score >= 45) return { label: 'Atenção', color: '#F0B429' };
  if (score >= 25) return { label: 'Risco', color: '#FF8A00' };
  return { label: 'Crítica', color: '#FF5C5C' };
}

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

/** Conta lançamentos futuros (paid=false) com data já passada. */
export function countOverdue(transactions: Transaction[], todayYmd: string): number {
  return transactions.filter((t) => t.type === 'expense' && !t.paid && t.date < todayYmd).length;
}
