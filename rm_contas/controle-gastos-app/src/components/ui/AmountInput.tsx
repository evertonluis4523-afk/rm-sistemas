import { useState } from 'react';
import { parseMoney } from '../../utils/currency';

interface AmountInputProps {
  value: number; // centavos
  onChange: (cents: number) => void;
  type?: 'income' | 'expense';
  autoFocus?: boolean;
}

/** Campo de valor grande e centralizado, usado no formulário de lançamento. */
export function AmountInput({ value, onChange, type = 'expense', autoFocus }: AmountInputProps) {
  const [text, setText] = useState(value ? (value / 100).toFixed(2).replace('.', ',') : '');

  return (
    <div className="center" style={{ padding: '6px 0 8px' }}>
      <span style={{ fontSize: 22, fontWeight: 700, color: 'var(--text-2)', verticalAlign: 16, marginRight: 4 }}>R$</span>
      <input
        autoFocus={autoFocus}
        inputMode="decimal"
        placeholder="0,00"
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          onChange(parseMoney(e.target.value));
        }}
        style={{
          fontSize: 48,
          fontWeight: 800,
          textAlign: 'center',
          border: 'none',
          outline: 'none',
          background: 'transparent',
          width: '62%',
          maxWidth: 280,
          fontFamily: 'var(--font-mono)',
          color: type === 'expense' ? 'var(--expense)' : 'var(--income)',
        }}
      />
    </div>
  );
}
