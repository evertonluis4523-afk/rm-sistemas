import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { uid } from '../utils/id';
import type { Category, CategoryType } from '../models';
import { logHistory } from '../services/historyLogger';

export function useCategories(type?: CategoryType) {
  const categories = useLiveQuery(async () => {
    const all = (await db.categories.toArray()).sort((a, b) => a.name.localeCompare(b.name, 'pt-BR'));
    return type ? all.filter((c) => c.type === type) : all;
  }, [type]);

  return {
    categories: categories ?? [],
    loading: categories === undefined,
    async create(data: Omit<Category, 'id' | 'createdAt' | 'isDefault'>) {
      const category: Category = { ...data, id: uid(), isDefault: false, createdAt: Date.now() };
      await db.categories.add(category);
      await logHistory('category', category.id, 'create', `Categoria criada: ${category.name}`);
      return category;
    },
    async update(id: string, patch: Partial<Category>) {
      await db.categories.update(id, patch);
      await logHistory('category', id, 'update', 'Categoria atualizada');
    },
    async remove(id: string) {
      const inUse = await db.transactions.where('categoryId').equals(id).count();
      if (inUse > 0) throw new Error('Esta categoria possui lançamentos e não pode ser removida.');
      await db.categories.delete(id);
      await logHistory('category', id, 'delete', 'Categoria removida');
    },
  };
}

export function useCategoryMap() {
  const categories = useLiveQuery(() => db.categories.toArray(), []);
  const map = new Map((categories ?? []).map((c) => [c.id, c]));
  return map;
}
