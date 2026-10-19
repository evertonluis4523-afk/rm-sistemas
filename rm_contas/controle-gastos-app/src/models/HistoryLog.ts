export type HistoryEntity = 'transaction' | 'account' | 'card' | 'category' | 'goal' | 'budget' | 'recurring';
export type HistoryAction = 'create' | 'update' | 'delete';

export interface HistoryLog {
  id: string;
  entity: HistoryEntity;
  entityId: string;
  action: HistoryAction;
  summary: string;
  timestamp: number;
}
