import { type InputHTMLAttributes, type ReactNode, type TextareaHTMLAttributes } from 'react';

interface FieldProps {
  label?: string;
  hint?: string;
  error?: string;
  children: ReactNode;
}

export function Field({ label, hint, error, children }: FieldProps) {
  return (
    <div className="field">
      {label && <label>{label}</label>}
      {children}
      {hint && !error && <span className="dim" style={{ fontSize: 12, padding: '0 2px' }}>{hint}</span>}
      {error && <span style={{ fontSize: 12, color: 'var(--expense)', padding: '0 2px' }}>{error}</span>}
    </div>
  );
}

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={`input ${props.className ?? ''}`} {...props} />;
}

export function Textarea(props: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={`input ${props.className ?? ''}`} {...props} />;
}

export function IconInput({ icon, ...props }: { icon: string } & InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className="input-icon-wrap">
      <span className="msr">{icon}</span>
      <input className="input" {...props} />
    </div>
  );
}
