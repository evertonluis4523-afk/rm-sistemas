import { useEffect, useState } from 'react';
import { BottomSheet } from '../ui/BottomSheet';
import { PinPad } from '../ui/PinPad';
import { useAuthLock, useToast } from '../../contexts';

type Mode = 'create' | 'change' | 'remove';
type Stage = 'current' | 'new' | 'confirm';

export function PinManageSheet({ open, mode, onClose }: { open: boolean; mode: Mode; onClose: () => void }) {
  const { setupPin, changePin, removePin } = useAuthLock();
  const { show } = useToast();
  const [stage, setStage] = useState<Stage>(mode === 'create' ? 'new' : 'current');
  const [currentPin, setCurrentPin] = useState('');
  const [newPin, setNewPin] = useState('');
  const [error, setError] = useState(false);

  useEffect(() => {
    if (open) {
      setStage(mode === 'create' ? 'new' : 'current');
      setCurrentPin('');
      setNewPin('');
    }
  }, [open, mode]);

  function shake() {
    setError(true);
    setTimeout(() => setError(false), 420);
  }

  async function handleCurrent(pin: string) {
    if (mode === 'remove') {
      const ok = await removePin(pin);
      if (ok) {
        show('PIN removido');
        onClose();
      } else shake();
      return;
    }
    // mode === 'change': valida ao trocar de fato, mas guardamos o PIN atual aqui.
    setCurrentPin(pin);
    setStage('new');
  }

  function handleNew(pin: string) {
    setNewPin(pin);
    setStage('confirm');
  }

  async function handleConfirm(pin: string) {
    if (pin !== newPin) {
      shake();
      setTimeout(() => setStage('new'), 420);
      return;
    }
    if (mode === 'create') {
      await setupPin(pin);
      show('PIN criado');
    } else {
      const ok = await changePin(currentPin, pin);
      if (!ok) {
        show('PIN atual incorreto');
        onClose();
        return;
      }
      show('PIN alterado');
    }
    onClose();
  }

  const title = mode === 'remove' ? 'Confirme seu PIN atual' : stage === 'current' ? 'Digite seu PIN atual' : stage === 'new' ? 'Novo PIN' : 'Confirme o novo PIN';

  return (
    <BottomSheet open={open} onClose={onClose} title={title}>
      <div className="center" style={{ padding: '10px 0 6px' }}>
        {stage === 'current' && <PinPad onComplete={handleCurrent} error={error} />}
        {stage === 'new' && <PinPad onComplete={handleNew} error={error} />}
        {stage === 'confirm' && <PinPad onComplete={handleConfirm} error={error} />}
      </div>
    </BottomSheet>
  );
}
