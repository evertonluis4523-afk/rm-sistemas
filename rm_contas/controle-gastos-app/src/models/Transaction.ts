export type TransactionType = 'income' | 'expense';
export type PaymentMethod = 'pix' | 'debit' | 'credit' | 'cash' | 'boleto' | 'transfer';

export interface InstallmentInfo {
  group: string;
  index: number;
  total: number;
}

export interface GeoLocation {
  lat: number;
  lng: number;
  label?: string;
}

export interface Transaction {
  id: string;
  type: TransactionType;
  /** Valor em centavos, sempre positivo. */
  amount: number;
  categoryId: string;
  accountId?: string;
  cardId?: string;
  method: PaymentMethod;
  /** Data no formato YYYY-MM-DD. */
  date: string;
  description?: string;
  note?: string;
  /** Foto/comprovante em data URL (JPEG comprimido). */
  photo?: string;
  location?: GeoLocation;
  installment?: InstallmentInfo;
  recurringId?: string;
  /** Falso quando é uma conta futura/agendada ainda não paga. */
  paid: boolean;
  createdAt: number;
  updatedAt: number;
}

export const PAYMENT_METHODS: { id: PaymentMethod; name: string }[] = [
  { id: 'pix', name: 'Pix' },
  { id: 'debit', name: 'Débito' },
  { id: 'credit', name: 'Crédito' },
  { id: 'cash', name: 'Dinheiro' },
  { id: 'boleto', name: 'Boleto' },
  { id: 'transfer', name: 'Transferência' },
];
