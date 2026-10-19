import type { Transaction, Category } from '../../models';
import { formatMoney } from '../../utils/currency';
import { Icon } from '../ui/Icon';

export function TransactionRow({
  tx,
  category,
  accountName,
  onClick,
}: {
  tx: Transaction;
  category?: Category;
  accountName?: string;
  onClick?: () => void;
}) {
  const color = category?.color ?? '#8E95A2';
  const negative = tx.type === 'expense';
  const parcela = tx.installment ? ` · ${tx.installment.index}/${tx.installment.total}` : '';
  const pend = negative && !tx.paid ? ' · a pagar' : '';
  return (
    <div className="list-item" onClick={onClick} role={onClick ? 'button' : undefined} style={{ cursor: onClick ? 'pointer' : 'default', gap: 12 }}>
      <div style={{ width: 42, height: 42, borderRadius: 14, display: 'grid', placeItems: 'center', flexShrink: 0, background: color + '22' }}>
        <Icon name={category?.icon ?? 'receipt_long'} style={{ color }} />
      </div>
      <div className="li-mid">
        <div className="li-t" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {tx.description || category?.name || 'Lançamento'}
        </div>
        <div className="li-s">
          {category?.name}
          {accountName ? ` · ${accountName}` : ''}
          {parcela}
          {pend}
        </div>
      </div>
      <strong className="mono" style={{ fontSize: 15, color: negative ? 'var(--expense)' : 'var(--income)' }}>
        {negative ? '-' : '+'}
        {formatMoney(tx.amount)}
      </strong>
    </div>
  );
}
