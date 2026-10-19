import { useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { BottomSheet } from '../ui/BottomSheet';
import { Field, Input } from '../ui/Input';
import { Chip } from '../ui/Chip';
import { ColorPicker } from '../ui/ColorPicker';
import { Button } from '../ui/Button';
import { useCards } from '../../hooks/useCards';
import { useAccounts } from '../../hooks/useAccounts';
import { useToast } from '../../contexts';
import { parseMoney } from '../../utils/currency';
import { CARD_BRANDS, CARD_COLORS, type Card, type CardBrand } from '../../models';

const schema = z.object({
  name: z.string().min(1, 'Informe um nome'),
  brand: z.custom<CardBrand>(),
  color: z.string(),
  limitText: z.string(),
  closingDay: z.string(),
  dueDay: z.string(),
  linkedAccountId: z.string().optional(),
});
type FormValues = z.infer<typeof schema>;

export function CardFormSheet({ open, onClose, editing }: { open: boolean; onClose: () => void; editing: Card | null }) {
  const { create, update, archive } = useCards();
  const { accounts } = useAccounts();
  const { show } = useToast();
  const { control, handleSubmit, watch, setValue, reset, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', brand: 'visa', color: CARD_COLORS[0], limitText: '0,00', closingDay: '1', dueDay: '10' },
  });

  useEffect(() => {
    if (!open) return;
    if (editing) {
      reset({
        name: editing.name, brand: editing.brand, color: editing.color,
        limitText: (editing.limit / 100).toFixed(2).replace('.', ','),
        closingDay: String(editing.closingDay), dueDay: String(editing.dueDay), linkedAccountId: editing.linkedAccountId,
      });
    } else {
      reset({ name: '', brand: 'visa', color: CARD_COLORS[0], limitText: '0,00', closingDay: '1', dueDay: '10' });
    }
  }, [open, editing, reset]);

  async function onSubmit(values: FormValues) {
    const limit = parseMoney(values.limitText);
    const closingDay = Math.min(31, Math.max(1, Number(values.closingDay) || 1));
    const dueDay = Math.min(31, Math.max(1, Number(values.dueDay) || 1));
    const payload = { name: values.name, brand: values.brand, color: values.color, limit, closingDay, dueDay, linkedAccountId: values.linkedAccountId };
    if (editing) {
      await update(editing.id, payload);
      show('Cartão atualizado');
    } else {
      await create(payload);
      show('Cartão criado');
    }
    onClose();
  }

  async function handleArchive() {
    if (!editing) return;
    await archive(editing.id);
    show('Cartão arquivado');
    onClose();
  }

  return (
    <BottomSheet open={open} onClose={onClose} title={editing ? 'Editar cartão' : 'Novo cartão'}>
      <form onSubmit={handleSubmit(onSubmit)} className="stack">
        <Field label="Nome do cartão" error={errors.name?.message}>
          <Controller name="name" control={control} render={({ field }) => <Input {...field} placeholder="Ex.: Nubank Roxinho" />} />
        </Field>

        <Field label="Bandeira">
          <div className="chips">
            {CARD_BRANDS.map((b) => (
              <Chip key={b.id} on={watch('brand') === b.id} onClick={() => setValue('brand', b.id)}>
                {b.name}
              </Chip>
            ))}
          </div>
        </Field>

        <Field label="Cor">
          <ColorPicker value={watch('color')} onChange={(c) => setValue('color', c)} />
        </Field>

        <Field label="Limite total">
          <Controller name="limitText" control={control} render={({ field }) => <Input {...field} inputMode="decimal" placeholder="0,00" />} />
        </Field>

        <div className="row" style={{ gap: 10 }}>
          <Field label="Fechamento (dia)">
            <Controller name="closingDay" control={control} render={({ field }) => <Input {...field} type="number" min={1} max={31} />} />
          </Field>
          <Field label="Vencimento (dia)">
            <Controller name="dueDay" control={control} render={({ field }) => <Input {...field} type="number" min={1} max={31} />} />
          </Field>
        </div>

        {accounts.length > 0 && (
          <Field label="Conta vinculada (opcional)">
            <div className="chips">
              {accounts.map((a) => (
                <Chip key={a.id} on={watch('linkedAccountId') === a.id} onClick={() => setValue('linkedAccountId', watch('linkedAccountId') === a.id ? undefined : a.id)}>
                  {a.name}
                </Chip>
              ))}
            </div>
          </Field>
        )}

        <div className="sheet-actions">
          {editing && <Button type="button" variant="danger" icon="archive" onClick={handleArchive} style={{ flex: '0 0 auto' }}>Arquivar</Button>}
          <Button type="submit" variant="primary">{editing ? 'Salvar' : 'Criar cartão'}</Button>
        </div>
      </form>
    </BottomSheet>
  );
}
