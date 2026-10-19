import { db } from '../database/db';
import { uid } from '../utils/id';
import type { HistoryEntity, HistoryAction } from '../models';

/** Registra toda inclusão, edição e exclusão para o histórico auditável do app. */
export async function logHistory(entity: HistoryEntity, entityId: string, action: HistoryAction, summary: string): Promise<void> {
  await db.history.add({ id: uid(), entity, entityId, action, summary, timestamp: Date.now() });
}
