import { useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { BottomSheet } from '../ui/BottomSheet';
import { Field, Input } from '../ui/Input';
import { Seg } from '../ui/Seg';
import { ColorPicker } from '../ui/ColorPicker';
import { IconPicker } from '../ui/IconPicker';
import { Button } from '../ui/Button';
import { useCategories } from '../../hooks/useCategories';
import { useToast } from '../../contexts';
import { COLOR_CHOICES } from '../ui/ColorPicker';
import type { Category, CategoryType } from '../../models';

const schema = z.object({
  name: z.string().min(1, 'Informe um nome'),
  type: z.custom<CategoryType>(),
  color: z.string(),
  icon: z.string(),
});
type FormValues = z.infer<typeof schema>;

export function CategoryFormSheet({ open, onClose, editing, defaultType }: { open: boolean; onClose: () => void; editing: Category | null; defaultType: CategoryType }) {
  const { create, update } = useCategories();
  const { show } = useToast();
  const { control, handleSubmit, watch, setValue, reset, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', type: defaultType, color: COLOR_CHOICES[0], icon: 'category' },
  });

  useEffect(() => {
    if (!open) return;
    if (editing) reset({ name: editing.name, type: editing.type, color: editing.color, icon: editing.icon });
    else reset({ name: '', type: defaultType, color: COLOR_CHOICES[0], icon: 'category' });
  }, [open, editing, defaultType, reset]);

  async function onSubmit(values: FormValues) {
    if (editing) {
      await update(editing.id, values);
      show('Categoria atualizada');
    } else {
      await create(values);
      show('Categoria criada');
    }
    onClose();
  }

  return (
    <BottomSheet open={open} onClose={onClose} title={editing ? 'Editar categoria' : 'Nova categoria'}>
      <form onSubmit={handleSubmit(onSubmit)} className="stack">
        <Field label="Tipo">
          <Seg options={[{ id: 'expense', label: 'Despesa' }, { id: 'income', label: 'Receita' }]} value={watch('type')} onChange={(v) => setValue('type', v as CategoryType)} />
        </Field>
        <Field label="Nome" error={errors.name?.message}>
          <Controller name="name" control={control} render={({ field }) => <Input {...field} placeholder="Ex.: Assinaturas" />} />
        </Field>
        <Field label="Cor">
          <ColorPicker value={watch('color')} onChange={(c) => setValue('color', c)} />
        </Field>
        <Field label="Ícone">
          <IconPicker value={watch('icon')} onChange={(i) => setValue('icon', i)} color={watch('color')} />
        </Field>
        <div className="sheet-actions">
          <Button type="submit" variant="primary">{editing ? 'Salvar' : 'Criar categoria'}</Button>
        </div>
      </form>
    </BottomSheet>
  );
}
