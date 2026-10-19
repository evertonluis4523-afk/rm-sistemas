/** Orçamento: 'general' representa o teto mensal geral; demais ids são categoryId. */
export interface Budget {
  id: string;
  categoryId?: string;
  /** Em centavos. */
  amount: number;
  createdAt: number;
}
