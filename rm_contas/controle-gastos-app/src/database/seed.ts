import { db } from './db';
import { DEFAULT_CATEGORIES } from './defaultCategories';
import { DEFAULT_SETTINGS } from '../models';

/** Popula categorias padrão e configurações iniciais na primeira execução. Idempotente. */
export async function ensureSeeded(): Promise<void> {
  await db.transaction('rw', db.categories, db.settings, async () => {
    const catCount = await db.categories.count();
    if (catCount === 0) {
      const now = Date.now();
      await db.categories.bulkAdd(DEFAULT_CATEGORIES.map((c) => ({ ...c, createdAt: now })));
    }
    const settings = await db.settings.get('settings');
    if (!settings) {
      await db.settings.add(DEFAULT_SETTINGS);
    }
  });
}
