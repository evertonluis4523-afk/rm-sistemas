import { useState, useEffect } from 'react';
import { BottomSheet } from '../ui/BottomSheet';
import { AmountInput } from '../ui/AmountInput';
import { Button } from '../ui/Button';
import { useBudgets } from '../../hooks/useBudgets';
import { useToast } from '../../contexts';

interface BudgetInputSheetProps {
  open: boolean;
  title: string;
  currentAmount?: number;
  target?: string; // 'general' ou categoryId
  onClose: () => void;
}

export function BudgetInputSheet({ open, title, currentAmount, target, onClose }: BudgetInputSheetProps) {
  const { setGeneral, setCategory } = useBudgets();
  const { show } = useToast();
  const [amount, setAmount] = useState(0);

  useEffect(() => {
    if (open) setAmount(currentAmount ?? 0);
  }, [open, currentAmount]);

  async function handleSave(overrideAmount?: number) {
    if (!target) return;
    const value = overrideAmount ?? amount;
    if (target === 'general') await setGeneral(value);
    else await setCategory(target, value);
    show(value > 0 ? 'Limite definido' : 'Limite removido');
    onClose();
  }

  return (
    <BottomSheet open={open} onClose={onClose} title={title}>
      <AmountInput value={amount} onChange={setAmount} type="expense" autoFocus />
      <div className="sheet-actions">
        {currentAmount ? (
          <Button variant="ghost" onClick={() => handleSave(0)}>Remover</Button>
        ) : null}
        <Button variant="primary" onClick={() => handleSave()}>Salvar</Button>
      </div>
    </BottomSheet>
  );
}
