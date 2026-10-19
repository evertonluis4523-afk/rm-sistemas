import { useState } from 'react';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Icon } from '../components/ui/Icon';
import { EmptyState } from '../components/ui/EmptyState';
import { CreditCardTile } from '../components/CreditCardTile';
import { useCards } from '../hooks/useCards';
import { useMonth } from '../contexts';
import { CardFormSheet } from '../components/forms/CardFormSheet';
import type { Card as CardModel } from '../models';

export function Cards() {
  const { cards } = useCards();
  const { month } = useMonth();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<CardModel | null>(null);

  return (
    <>
      <PageTopBar
        title="Cartões"
        back
        rightAction={
          <button className="btn icon-only ghost" onClick={() => { setEditing(null); setOpen(true); }} aria-label="Novo cartão">
            <Icon name="add" />
          </button>
        }
      />
      <main className="view stack">
        {cards.length === 0 ? (
          <EmptyState icon="credit_card" title="Nenhum cartão cadastrado" subtitle="Adicione seus cartões de crédito para acompanhar limite, fatura e parcelas." />
        ) : (
          <div className="stack">
            {cards.map((c) => (
              <CreditCardTile key={c.id} card={c} month={month} onClick={() => { setEditing(c); setOpen(true); }} />
            ))}
          </div>
        )}
      </main>
      <CardFormSheet open={open} onClose={() => setOpen(false)} editing={editing} />
    </>
  );
}
