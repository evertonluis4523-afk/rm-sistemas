import { useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { BottomSheet } from '../ui/BottomSheet';
import { Field, Input } from '../ui/Input';
import { Chip } from '../ui/Chip';
import { Button } from '../ui/Button';
import { Icon } from '../ui/Icon';
import { useGoals } from '../../hooks/useGoals';
import { useToast } from '../../contexts';
import { parseMoney } from '../../utils/currency';
import { GOAL_PRESETS, type Goal, type GoalKind } from '../../models';

const schema = z.object({
  name: z.string().min(1, 'Informe um nome'),
  kind: z.custom<GoalKind>(),
  color: z.string(),
  icon: z.string(),
  targetText: z.string().min(1, 'Informe o valor da meta'),
  currentText: z.string(),
  targetDate: z.string().optional(),
});
type FormValues = z.infer<typeof schema>;

export function GoalFormSheet({ open, onClose, editing }: { open: boolean; onClose: () => void; editing: Goal | null }) {
  const { create, update, remove } = useGoals();
  const { show } = useToast();
  const { control, handleSubmit, watch, setValue, reset, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', kind: 'custom', color: GOAL_PRESETS[0].color, icon: GOAL_PRESETS[0].icon, targetText: '', currentText: '0,00', targetDate: '' },
  });

  useEffect(() => {
    if (!open) return;
    if (editing) {
      reset({
        name: editing.name, kind: editing.kind, color: editing.color, icon: editing.icon,
        targetText: (editing.targetAmount / 100).toFixed(2).replace('.', ','),
        currentText: (editing.currentAmount / 100).toFixed(2).replace('.', ','),
        targetDate: editing.targetDate ?? '',
      });
    } else {
      reset({ name: '', kind: 'custom', color: GOAL_PRESETS[0].color, icon: GOAL_PRESETS[0].icon, targetText: '', currentText: '0,00', targetDate: '' });
    }
  }, [open, editing, reset]);

  function pickPreset(p: (typeof GOAL_PRESETS)[number]) {
    setValue('kind', p.kind);
    setValue('color', p.color);
    setValue('icon', p.icon);
    if (!watch('name')) setValue('name', p.name);
  }

  async function onSubmit(values: FormValues) {
    const payload = {
      name: values.name, kind: values.kind, color: values.color, icon: values.icon,
      targetAmount: parseMoney(values.targetText), currentAmount: parseMoney(values.currentText),
      targetDate: values.targetDate || undefined,
    };
    if (editing) {
      await update(editing.id, payload);
      show('Meta atualizada');
    } else {
      await create(payload);
      show('Meta criada');
    }
    onClose();
  }

  async function handleDelete() {
    if (!editing) return;
    await remove(editing.id);
    show('Meta removida');
    onClose();
  }

  return (
    <BottomSheet open={open} onClose={onClose} title={editing ? 'Editar meta' : 'Nova meta'}>
      <form onSubmit={handleSubmit(onSubmit)} className="stack">
        <Field label="Tipo de meta">
          <div className="chips">
            {GOAL_PRESETS.map((p) => (
              <Chip key={p.kind} on={watch('kind') === p.kind} onClick={() => pickPreset(p)}>
                <Icon name={p.icon} size={14} /> {p.name}
              </Chip>
            ))}
          </div>
        </Field>
        <Field label="Nome da meta" error={errors.name?.message}>
          <Controller name="name" control={control} render={({ field }) => <Input {...field} placeholder="Ex.: Viagem para a praia" />} />
        </Field>
        <Field label="Valor desejado" error={errors.targetText?.message}>
          <Controller name="targetText" control={control} render={({ field }) => <Input {...field} inputMode="decimal" placeholder="0,00" />} />
        </Field>
        <Field label="Valor já economizado">
          <Controller name="currentText" control={control} render={({ field }) => <Input {...field} inputMode="decimal" placeholder="0,00" />} />
        </Field>
        <Field label="Data alvo (opcional)">
          <Controller name="targetDate" control={control} render={({ field }) => <Input {...field} type="date" />} />
        </Field>
        <div className="sheet-actions">
          {editing && <Button type="button" variant="danger" iconOnly icon="delete" onClick={handleDelete} style={{ flex: '0 0 52px' }} />}
          <Button type="submit" variant="primary">{editing ? 'Salvar' : 'Criar meta'}</Button>
        </div>
      </form>
    </BottomSheet>
  );
}
