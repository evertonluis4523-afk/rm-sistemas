import { useState } from 'react';
import { BottomSheet } from '../ui/BottomSheet';
import { AmountInput } from '../ui/AmountInput';
import { Button } from '../ui/Button';
import { useGoals } from '../../hooks/useGoals';
import { useToast } from '../../contexts';
import type { Goal } from '../../models';

export function ContributeSheet({ goal, onClose }: { goal: Goal | null; onClose: () => void }) {
  const { contribute } = useGoals();
  const { show } = useToast();
  const [amount, setAmount] = useState(0);

  async function handleSave() {
    if (!goal || amount <= 0) return;
    await contribute(goal.id, amount);
    show('Contribuição adicionada');
    setAmount(0);
    onClose();
  }

  return (
    <BottomSheet open={!!goal} onClose={onClose} title={goal ? `Adicionar a ${goal.name}` : ''}>
      <AmountInput value={amount} onChange={setAmount} type="income" autoFocus />
      <div className="sheet-actions">
        <Button variant="primary" onClick={handleSave}>Adicionar</Button>
      </div>
    </BottomSheet>
  );
}
