export type AccountKind = 'checking' | 'savings' | 'wallet' | 'cash' | 'investment';

export interface Account {
  id: string;
  name: string;
  bankPreset?: string;
  kind: AccountKind;
  color: string;
  icon: string;
  /** Saldo inicial em centavos (na criação da conta). O saldo atual é derivado somando os lançamentos vinculados. */
  balance: number;
  archived: boolean;
  createdAt: number;
  updatedAt: number;
}

export const BANK_PRESETS: { id: string; name: string; color: string }[] = [
  { id: 'nubank', name: 'Nubank', color: '#8A05BE' },
  { id: 'caixa', name: 'Caixa', color: '#0070AE' },
  { id: 'bb', name: 'Banco do Brasil', color: '#F7DC00' },
  { id: 'santander', name: 'Santander', color: '#EC0000' },
  { id: 'inter', name: 'Inter', color: '#FF7A00' },
  { id: 'itau', name: 'Itaú', color: '#EC7000' },
  { id: 'bradesco', name: 'Bradesco', color: '#CC092F' },
  { id: 'c6', name: 'C6 Bank', color: '#1B1B1B' },
  { id: 'picpay', name: 'PicPay', color: '#21C25E' },
  { id: 'dinheiro', name: 'Dinheiro', color: '#2ECC71' },
  { id: 'carteira', name: 'Carteira', color: '#FF8A00' },
];
