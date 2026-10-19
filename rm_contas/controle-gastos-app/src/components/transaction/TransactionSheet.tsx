import { useEffect, useState } from 'react';
import { BottomSheet } from '../ui/BottomSheet';
import { AmountInput } from '../ui/AmountInput';
import { Field, Textarea } from '../ui/Input';
import { Chip } from '../ui/Chip';
import { Switch } from '../ui/Switch';
import { Button } from '../ui/Button';
import { Icon } from '../ui/Icon';
import { useCategories } from '../../hooks/useCategories';
import { useAccounts } from '../../hooks/useAccounts';
import { useCards } from '../../hooks/useCards';
import { useRecurring } from '../../hooks/useRecurring';
import { transactionMutations } from '../../hooks/useTransactions';
import { compressImage } from '../../utils/image';
import { ymd } from '../../utils/date';
import { useToast } from '../../contexts';
import { PAYMENT_METHODS, type PaymentMethod, type Transaction, type TransactionType } from '../../models';

interface TransactionSheetProps {
  open: boolean;
  onClose: () => void;
  editing?: Transaction | null;
  defaultType?: TransactionType;
}

export function TransactionSheet({ open, onClose, editing, defaultType = 'expense' }: TransactionSheetProps) {
  const { show } = useToast();
  const { categories } = useCategories();
  const { accounts } = useAccounts();
  const { cards } = useCards();
  const { create: createRecurring } = useRecurring();
  const mutations = transactionMutations();

  const [type, setType] = useState<TransactionType>(defaultType);
  const [amount, setAmount] = useState(0);
  const [catId, setCatId] = useState<string | null>(null);
  const [accountId, setAccountId] = useState<string | undefined>(undefined);
  const [cardId, setCardId] = useState<string | undefined>(undefined);
  const [method, setMethod] = useState<PaymentMethod>('pix');
  const [date, setDate] = useState(ymd(new Date()));
  const [description, setDescription] = useState('');
  const [note, setNote] = useState('');
  const [photo, setPhoto] = useState<string | undefined>(undefined);
  const [installments, setInstallments] = useState(1);
  const [recurring, setRecurring] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    if (editing) {
      setType(editing.type);
      setAmount(editing.amount);
      setCatId(editing.categoryId);
      setAccountId(editing.accountId);
      setCardId(editing.cardId);
      setMethod(editing.method);
      setDate(editing.date);
      setDescription(editing.description ?? '');
      setNote(editing.note ?? '');
      setPhoto(editing.photo);
      setInstallments(editing.installment?.total ?? 1);
      setRecurring(!!editing.recurringId);
    } else {
      setType(defaultType);
      setAmount(0);
      setCatId(null);
      setAccountId(accounts[0]?.id);
      setCardId(undefined);
      setMethod('pix');
      setDate(ymd(new Date()));
      setDescription('');
      setNote('');
      setPhoto(undefined);
      setInstallments(1);
      setRecurring(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, editing]);

  const catsOfType = categories.filter((c) => c.type === type);

  async function handlePhoto(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const dataUrl = await compressImage(file);
      setPhoto(dataUrl);
    } catch {
      show('Não foi possível processar a imagem');
    }
  }

  async function handleSave() {
    if (amount <= 0) return show('Informe um valor');
    if (!catId) return show('Escolha uma categoria');
    setSaving(true);
    try {
      if (editing) {
        await mutations.update(editing.id, {
          type,
          amount,
          categoryId: catId,
          accountId,
          cardId: method === 'credit' ? cardId : undefined,
          method,
          date,
          description,
          note,
          photo,
        });
        show('Lançamento atualizado');
      } else {
        await mutations.create({
          type,
          amount,
          categoryId: catId,
          accountId,
          cardId: method === 'credit' ? cardId : undefined,
          method,
          date,
          description,
          note,
          photo,
          paid: date <= ymd(new Date()),
          installments: method === 'credit' ? installments : 1,
        });
        if (recurring) {
          await createRecurring({ type, amount, categoryId: catId, accountId, cardId, method, day: Number(date.slice(8, 10)), description });
        }
        show(type === 'income' ? 'Receita adicionada' : 'Gasto registrado');
      }
      onClose();
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!editing) return;
    if (editing.installment) {
      await mutations.removeInstallmentGroup(editing.installment.group);
    } else {
      await mutations.remove(editing.id);
    }
    show('Lançamento removido');
    onClose();
  }

  return (
    <BottomSheet open={open} onClose={onClose} title={editing ? 'Editar lançamento' : 'Novo lançamento'}>
      <div className="type-toggle seg" style={{ marginBottom: 4 }}>
        <button className={type === 'expense' ? 'on' : ''} onClick={() => { setType('expense'); setCatId(null); }} style={{ color: type === 'expense' ? 'var(--expense)' : undefined }}>
          Despesa
        </button>
        <button className={type === 'income' ? 'on' : ''} onClick={() => { setType('income'); setCatId(null); }} style={{ color: type === 'income' ? 'var(--income)' : undefined }}>
          Receita
        </button>
      </div>

      <AmountInput value={amount} onChange={setAmount} type={type} autoFocus={!editing} />

      <Field label="Categoria">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
          {catsOfType.map((c) => (
            <button
              key={c.id}
              type="button"
              onClick={() => setCatId(c.id)}
              style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, padding: '10px 4px',
                borderRadius: 13, border: `1.5px solid ${catId === c.id ? c.color : 'var(--line)'}`,
                background: catId === c.id ? c.color + '1F' : 'var(--surface)',
              }}
            >
              <span className="avatar" style={{ width: 36, height: 36, background: c.color + '26', color: c.color }}>
                <Icon name={c.icon} size={19} />
              </span>
              <span style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--text-2)', textAlign: 'center', lineHeight: 1.2 }}>{c.name}</span>
            </button>
          ))}
        </div>
      </Field>

      <Field label="Data">
        <input type="date" className="input" value={date} onChange={(e) => setDate(e.target.value)} />
      </Field>

      {accounts.length > 0 && (
        <Field label="Conta">
          <div className="chips">
            {accounts.map((a) => (
              <Chip key={a.id} on={accountId === a.id} onClick={() => setAccountId(a.id)}>
                {a.name}
              </Chip>
            ))}
          </div>
        </Field>
      )}

      <Field label="Forma de pagamento">
        <div className="chips">
          {PAYMENT_METHODS.map((m) => (
            <Chip key={m.id} on={method === m.id} onClick={() => setMethod(m.id)}>
              {m.name}
            </Chip>
          ))}
        </div>
      </Field>

      {method === 'credit' && cards.length > 0 && (
        <Field label="Cartão">
          <div className="chips">
            {cards.map((c) => (
              <Chip key={c.id} on={cardId === c.id} onClick={() => setCardId(c.id)}>
                {c.name}
              </Chip>
            ))}
          </div>
        </Field>
      )}

      {method === 'credit' && !editing && (
        <Field label={`Parcelas: ${installments}x de ${amount ? (amount / installments / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }) : '—'}`}>
          <input type="range" min={1} max={24} value={installments} onChange={(e) => setInstallments(Number(e.target.value))} />
        </Field>
      )}

      <Field label="Descrição">
        <input className="input" placeholder="Ex.: Almoço, mercado da semana..." value={description} onChange={(e) => setDescription(e.target.value)} />
      </Field>

      <Field label="Observação (opcional)">
        <Textarea placeholder="Detalhes adicionais..." rows={2} value={note} onChange={(e) => setNote(e.target.value)} />
      </Field>

      <Field label="Comprovante (opcional)">
        {photo ? (
          <div style={{ position: 'relative', width: 88 }}>
            <img src={photo} alt="Comprovante" style={{ width: 88, height: 88, objectFit: 'cover', borderRadius: 12 }} />
            <button className="btn icon-only danger" style={{ position: 'absolute', top: -8, right: -8, width: 28, height: 28 }} onClick={() => setPhoto(undefined)}>
              <Icon name="close" size={16} />
            </button>
          </div>
        ) : (
          <label className="btn secondary sm" style={{ width: 'fit-content' }}>
            <Icon name="photo_camera" />
            Anexar foto
            <input type="file" accept="image/*" capture="environment" className="hidden" onChange={handlePhoto} />
          </label>
        )}
      </Field>

      {!editing && (
        <Field label="">
          <div className="list-item" style={{ border: '1px solid var(--line)', borderRadius: 12, padding: '12px 14px' }}>
            <div className="li-mid">
              <div className="li-t">Repetir todo mês</div>
              <div className="li-s">Cria automaticamente como conta fixa</div>
            </div>
            <Switch on={recurring} onClick={() => setRecurring((v) => !v)} ariaLabel="Repetir todo mês" />
          </div>
        </Field>
      )}

      <div className="sheet-actions">
        {editing && (
          <Button variant="danger" iconOnly icon="delete" onClick={handleDelete} aria-label="Remover" style={{ flex: '0 0 52px' }} />
        )}
        <Button variant="primary" onClick={handleSave} disabled={saving}>
          {editing ? 'Salvar alterações' : 'Adicionar'}
        </Button>
      </div>
    </BottomSheet>
  );
}
