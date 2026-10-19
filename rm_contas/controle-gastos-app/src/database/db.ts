import Dexie, { type Table } from 'dexie';
import type { Account, Card, Category, Transaction, Recurring, Goal, Budget, AppSettings, HistoryLog } from '../models';

class OrangeFinanceDB extends Dexie {
  accounts!: Table<Account, string>;
  cards!: Table<Card, string>;
  categories!: Table<Category, string>;
  transactions!: Table<Transaction, string>;
  recurring!: Table<Recurring, string>;
  goals!: Table<Goal, string>;
  budgets!: Table<Budget, string>;
  settings!: Table<AppSettings, string>;
  history!: Table<HistoryLog, string>;

  constructor() {
    super('orange-finance-db');
    // Observação: IndexedDB não aceita `boolean` como chave de índice, então campos
    // booleanos (archived, active, paid) NÃO entram no schema — são filtrados em memória.
    this.version(1).stores({
      accounts: 'id, kind, updatedAt',
      cards: 'id, updatedAt',
      categories: 'id, type',
      transactions: 'id, type, categoryId, accountId, cardId, date, recurringId, [type+date]',
      recurring: 'id',
      goals: 'id, updatedAt',
      budgets: 'id, categoryId',
      settings: 'id',
      history: 'id, entity, entityId, timestamp',
    });
  }
}

export const db = new OrangeFinanceDB();
