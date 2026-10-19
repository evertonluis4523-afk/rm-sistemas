import { useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { BottomSheet } from '../ui/BottomSheet';
import { Field, Input } from '../ui/Input';
import { Chip } from '../ui/Chip';
import { Button } from '../ui/Button';
import { useAccounts } from '../../hooks/useAccounts';
import { useToast } from '../../contexts';
import { parseMoney, formatMoney } from '../../utils/currency';
import { BANK_PRESETS, type Account, type AccountKind } from '../../models';

const schema = z.object({
  name: z.string().min(1, 'Informe um nome'),
  kind: z.custom<AccountKind>(),
  bankPreset: z.string().optional(),
  color: z.string(),
  icon: z.string(),
  balanceText: z.string(),
});
type FormValues = z.infer<typeof schema>;

const KIND_OPTIONS: { id: AccountKind; label: string }[] = [
  { id: 'checking', label: 'Conta corrente' },
  { id: 'savings', label: 'Poupança' },
  { id: 'wallet', label: 'Carteira' },
  { id: 'cash', label: 'Dinheiro' },
  { id: 'investment', label: 'Investimento' },
];

export function AccountFormSheet({ open, onClose, editing }: { open: boolean; onClose: () => void; editing: Account | null }) {
  const { create, update, archive } = useAccounts();
  const { show } = useToast();
  const { control, handleSubmit, watch, setValue, reset, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', kind: 'checking', color: '#FF8A00', icon: 'account_balance', balanceText: '0,00' },
  });

  useEffect(() => {
    if (!open) return;
    if (editing) {
      reset({ name: editing.name, kind: editing.kind, bankPreset: editing.bankPreset, color: editing.color, icon: editing.icon, balanceText: (editing.balance / 100).toFixed(2).replace('.', ',') });
    } else {
      reset({ name: '', kind: 'checking', color: '#FF8A00', icon: 'account_balance', balanceText: '0,00' });
    }
  }, [open, editing, reset]);

  const color = watch('color');

  async function onSubmit(values: FormValues) {
    const balance = parseMoney(values.balanceText);
    if (editing) {
      await update(editing.id, { name: values.name, kind: values.kind, bankPreset: values.bankPreset, color: values.color, icon: values.icon, balance });
      show('Conta atualizada');
    } else {
      await create({ name: values.name, kind: values.kind, bankPreset: values.bankPreset, color: values.color, icon: values.icon, balance });
      show('Conta criada');
    }
    onClose();
  }

  async function handleArchive() {
    if (!editing) return;
    await archive(editing.id);
    show('Conta arquivada');
    onClose();
  }

  return (
    <BottomSheet open={open} onClose={onClose} title={editing ? 'Editar conta' : 'Nova conta'}>
      <form onSubmit={handleSubmit(onSubmit)} className="stack">
        <Field label="Banco / instituição">
          <div className="chips">
            {BANK_PRESETS.map((b) => (
              <Chip key={b.id} on={watch('bankPreset') === b.id} onClick={() => { setValue('bankPreset', b.id); setValue('color', b.color); if (!watch('name')) setValue('name', b.name); }}>
                {b.name}
              </Chip>
            ))}
          </div>
        </Field>

        <Field label="Nome da conta" error={errors.name?.message}>
          <Controller name="name" control={control} render={({ field }) => <Input {...field} placeholder="Ex.: Nubank, Carteira..." />} />
        </Field>

        <Field label="Tipo">
          <div className="chips">
            {KIND_OPTIONS.map((k) => (
              <Chip key={k.id} on={watch('kind') === k.id} onClick={() => setValue('kind', k.id)}>
                {k.label}
              </Chip>
            ))}
          </div>
        </Field>

        <Field label={editing ? 'Saldo inicial' : `Saldo inicial ${formatMoney(parseMoney(watch('balanceText') || '0'))}`}>
          <Controller name="balanceText" control={control} render={({ field }) => <Input {...field} inputMode="decimal" placeholder="0,00" />} />
        </Field>

        <div className="sheet-actions">
          {editing && <Button type="button" variant="danger" icon="archive" onClick={handleArchive} style={{ flex: '0 0 auto' }}>Arquivar</Button>}
          <Button type="submit" variant="primary" style={{ background: `linear-gradient(135deg, ${color}, ${color})` }}>
            {editing ? 'Salvar' : 'Criar conta'}
          </Button>
        </div>
      </form>
    </BottomSheet>
  );
}
