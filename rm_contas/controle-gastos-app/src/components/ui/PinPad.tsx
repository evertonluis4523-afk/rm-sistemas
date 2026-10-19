import { useState } from 'react';
import { motion } from 'framer-motion';
import { Icon } from './Icon';

interface PinPadProps {
  length?: number;
  onComplete: (pin: string) => void;
  error?: boolean;
  disabled?: boolean;
}

export function PinPad({ length = 4, onComplete, error, disabled }: PinPadProps) {
  const [value, setValue] = useState('');

  function press(digit: string) {
    if (disabled) return;
    const next = (value + digit).slice(0, length);
    setValue(next);
    if (next.length === length) {
      onComplete(next);
      setTimeout(() => setValue(''), 220);
    }
  }
  function backspace() {
    setValue((v) => v.slice(0, -1));
  }

  return (
    <div className="stack" style={{ width: '100%', maxWidth: 300, margin: '0 auto' }}>
      <motion.div
        animate={error ? { x: [0, -10, 10, -8, 8, 0] } : {}}
        transition={{ duration: 0.4 }}
        style={{ display: 'flex', justifyContent: 'center', gap: 14, marginBottom: 28 }}
      >
        {Array.from({ length }).map((_, i) => (
          <span
            key={i}
            style={{
              width: 16,
              height: 16,
              borderRadius: '50%',
              background: i < value.length ? (error ? 'var(--expense)' : 'var(--primary)') : 'transparent',
              border: `2px solid ${i < value.length ? (error ? 'var(--expense)' : 'var(--primary)') : 'var(--line)'}`,
              transition: 'all 120ms ease',
            }}
          />
        ))}
      </motion.div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
        {['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'].map((k, i) =>
          k === '' ? (
            <div key={i} />
          ) : k === 'back' ? (
            <button
              key={i}
              onClick={backspace}
              className="row"
              style={{ justifyContent: 'center', width: 68, height: 68, justifySelf: 'center', borderRadius: '50%', color: 'var(--text-2)' }}
              aria-label="Apagar"
            >
              <Icon name="backspace" />
            </button>
          ) : (
            <button
              key={i}
              onClick={() => press(k)}
              disabled={disabled}
              style={{
                width: 68, height: 68, justifySelf: 'center', borderRadius: '50%', fontSize: 22, fontWeight: 700,
                background: 'var(--surface-2)', color: 'var(--text)',
              }}
            >
              {k}
            </button>
          )
        )}
      </div>
    </div>
  );
}
