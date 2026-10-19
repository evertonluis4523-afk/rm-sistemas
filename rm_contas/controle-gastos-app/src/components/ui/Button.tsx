import { type ButtonHTMLAttributes, type ReactNode } from 'react';
import { Icon } from './Icon';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'success';
  size?: 'md' | 'sm';
  icon?: string;
  iconOnly?: boolean;
  children?: ReactNode;
}

export function Button({ variant = 'secondary', size = 'md', icon, iconOnly, className = '', children, ...rest }: ButtonProps) {
  const classes = ['btn', variant, size === 'sm' ? 'sm' : '', iconOnly ? 'icon-only' : '', className].filter(Boolean).join(' ');
  return (
    <button className={classes} {...rest}>
      {icon && <Icon name={icon} />}
      {children}
    </button>
  );
}

export function FabButton({ onClick, icon = 'add', ariaLabel = 'Novo lançamento' }: { onClick: () => void; icon?: string; ariaLabel?: string }) {
  return (
    <button className="btn fab" onClick={onClick} aria-label={ariaLabel}>
      <Icon name={icon} />
    </button>
  );
}
