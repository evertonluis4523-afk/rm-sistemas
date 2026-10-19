export type CardBrand = 'visa' | 'mastercard' | 'elo' | 'amex' | 'hipercard' | 'other';

export interface Card {
  id: string;
  name: string;
  brand: CardBrand;
  color: string;
  /** Limite total em centavos. */
  limit: number;
  /** Fatura atual (comprometido) em centavos — calculado a partir dos lançamentos. */
  closingDay: number;
  dueDay: number;
  linkedAccountId?: string;
  archived: boolean;
  createdAt: number;
  updatedAt: number;
}

export const CARD_BRANDS: { id: CardBrand; name: string }[] = [
  { id: 'visa', name: 'Visa' },
  { id: 'mastercard', name: 'Mastercard' },
  { id: 'elo', name: 'Elo' },
  { id: 'amex', name: 'American Express' },
  { id: 'hipercard', name: 'Hipercard' },
  { id: 'other', name: 'Outra' },
];

export const CARD_COLORS = ['#FF8A00', '#8A05BE', '#0070AE', '#EC0000', '#21C25E', '#4EA1FF', '#1B1B1B', '#CC092F'];
