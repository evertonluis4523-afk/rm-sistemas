import { useState } from 'react';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Icon } from '../components/ui/Icon';
import { Seg } from '../components/ui/Seg';
import { useCategories } from '../hooks/useCategories';
import { useToast } from '../contexts';
import { CategoryFormSheet } from '../components/forms/CategoryFormSheet';
import type { Category, CategoryType } from '../models';

export function Categories() {
  const [type, setType] = useState<CategoryType>('expense');
  const { categories, remove } = useCategories(type);
  const { show } = useToast();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);

  async function handleRemove(id: string) {
    try {
      await remove(id);
      show('Categoria removida');
    } catch (e) {
      show(e instanceof Error ? e.message : 'Não foi possível remover');
    }
  }

  return (
    <>
      <PageTopBar
        title="Categorias"
        back
        rightAction={
          <button className="btn icon-only ghost" onClick={() => { setEditing(null); setOpen(true); }} aria-label="Nova categoria">
            <Icon name="add" />
          </button>
        }
      />
      <main className="view stack">
        <Seg
          options={[{ id: 'expense', label: 'Despesas' }, { id: 'income', label: 'Receitas' }]}
          value={type}
          onChange={(v) => setType(v as CategoryType)}
        />
        <div className="list">
          {categories.map((c) => (
            <div key={c.id} className="list-item">
              <span className="avatar" style={{ background: c.color + '26', color: c.color }}>
                <Icon name={c.icon} />
              </span>
              <div className="li-mid">
                <div className="li-t">{c.name}</div>
                {c.isDefault && <div className="li-s">Categoria padrão</div>}
              </div>
              <button className="btn icon-only ghost" onClick={() => { setEditing(c); setOpen(true); }} aria-label="Editar">
                <Icon name="edit" size={18} />
              </button>
              <button className="btn icon-only ghost" onClick={() => handleRemove(c.id)} aria-label="Remover">
                <Icon name="delete" size={18} style={{ color: 'var(--expense)' }} />
              </button>
            </div>
          ))}
        </div>
      </main>
      <CategoryFormSheet open={open} onClose={() => setOpen(false)} editing={editing} defaultType={type} />
    </>
  );
}
