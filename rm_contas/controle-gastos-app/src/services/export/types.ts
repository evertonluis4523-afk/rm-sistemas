export interface ReportRow {
  date: string;
  description: string;
  category: string;
  account: string;
  method: string;
  type: 'income' | 'expense';
  amount: number; // centavos
}

export interface ReportMeta {
  title: string;
  periodLabel: string;
  totalIncome: number;
  totalExpense: number;
  generatedAt: number;
}
