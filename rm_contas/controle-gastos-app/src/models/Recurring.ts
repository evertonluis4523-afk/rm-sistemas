import type { PaymentMethod, TransactionType } from './Transaction';

export interface Recurring {
  id: string;
  type: TransactionType;
  amount: number;
  categoryId: string;
  accountId?: string;
  cardId?: string;
  method: PaymentMethod;
  /** Dia do mês (1-28 recomendado para evitar meses curtos). */
  day: number;
  description?: string;
  active: boolean;
  createdAt: number;
}
