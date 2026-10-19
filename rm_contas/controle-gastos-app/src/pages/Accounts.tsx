import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Card } from '../components/ui/Card';
import { Icon } from '../components/ui/Icon';
import { EmptyState } from '../components/ui/EmptyState';
import { useAccounts } from '../hooks/useAccounts';
import { useAccountBalances } from '../hooks/useAccountBalances';
import { useCards } from '../hooks/useCards';
import { formatMoney } from '../utils/currency';
import { AccountFormSheet } from '../components/forms/AccountFormSheet';
import { CreditCardTile } from '../components/CreditCardTile';
import { useMonth } from '../contexts';
import type { Account } from '../models';

export function Accounts() {
  const navigate = useNavigate();
  const { month } = useMonth();
  const { accounts } = useAccounts();
  const { balances } = useAccountBalances();
  const { cards } = useCards();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Account | null>(null);

  return (
    <>
      <PageTopBar
        title="Carteira"
        rightAction={
          <div className="row" style={{ gap: 6 }}>
            <button className="btn icon-only ghost" onClick={() => navigate('/cartoes')} aria-label="Cartões de crédito">
              <Icon name="credit_card" />
            </button>
            <button className="btn icon-only ghost" onClick={() => { setEditing(null); setOpen(true); }} aria-label="Nova conta">
              <Icon name="add" />
            </button>
          </div>
        }
      />
      <main className="view stack">
        {accounts.length === 0 ? (
          <EmptyState icon="account_balance" title="Nenhuma conta cadastrada" subtitle="Adicione suas contas bancárias, carteira e dinheiro para acompanhar o saldo." />
        ) : (
          <div className="stack">
            {accounts.map((a) => (
              <Card key={a.id} interactive onClick={() => { setEditing(a); setOpen(true); }} className="row-between">
                <div className="row" style={{ gap: 12 }}>
                  <span className="avatar" style={{ background: a.color + '26', color: a.color }}>
                    <Icon name={a.icon} />
                  </span>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 14.5 }}>{a.name}</div>
                    <div className="dim" style={{ fontSize: 11.5, textTransform: 'capitalize' }}>{kindLabel(a.kind)}</div>
                  </div>
                </div>
                <div className="mono" style={{ fontWeight: 800, fontSize: 15 }}>{formatMoney(balances.get(a.id) ?? a.balance)}</div>
              </Card>
            ))}
          </div>
        )}

        {/* Cartões de crédito (visual de cartãozinho) */}
        <div className="row-between" style={{ margin: '14px 4px 2px' }}>
          <h2 style={{ fontSize: 16, fontWeight: 700 }}>Cartões</h2>
          <button className="dim" style={{ fontSize: 13, fontWeight: 600 }} onClick={() => navigate('/cartoes')}>Gerenciar</button>
        </div>
        {cards.length === 0 ? (
          <Card interactive onClick={() => navigate('/cartoes')} className="row-between">
            <div className="row" style={{ gap: 12 }}>
              <span className="avatar" style={{ background: 'var(--primary-soft)', color: 'var(--primary)' }}>
                <Icon name="credit_card" />
              </span>
              <div>
                <div style={{ fontWeight: 700, fontSize: 14.5 }}>Adicionar cartão de crédito</div>
                <div className="dim" style={{ fontSize: 11.5 }}>Limite, fatura e parcelas</div>
              </div>
            </div>
            <Icon name="chevron_right" style={{ color: 'var(--text-3)' }} />
          </Card>
        ) : (
          <div className="stack">
            {cards.map((c) => (
              <CreditCardTile key={c.id} card={c} month={month} onClick={() => navigate('/cartoes')} />
            ))}
          </div>
        )}
      </main>
      <AccountFormSheet open={open} onClose={() => setOpen(false)} editing={editing} />
    </>
  );
}

function kindLabel(kind: Account['kind']): string {
  return { checking: 'Conta corrente', savings: 'Poupança', wallet: 'Carteira', cash: 'Dinheiro', investment: 'Investimento' }[kind];
}
