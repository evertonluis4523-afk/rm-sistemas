import { ICON_CODEPOINTS } from './iconCodepoints';

interface IconProps {
  name: string;
  filled?: boolean;
  size?: number;
  className?: string;
  style?: React.CSSProperties;
}

/**
 * Wrapper para o conjunto de ícones Material Symbols (Rounded), auto-hospedado
 * como subset (apenas os glifos usados no app) referenciado por codepoint Unicode
 * — funciona 100% offline, sem depender de ligadura de texto nem do Google Fonts.
 */
export function Icon({ name, filled, size = 24, className = '', style }: IconProps) {
  const char = ICON_CODEPOINTS[name];
  if (!char && import.meta.env.DEV) {
    // eslint-disable-next-line no-console
    console.warn(`Ícone "${name}" não está no subset (src/components/ui/iconCodepoints.ts).`);
  }
  return (
    <span className={`msr${filled ? ' filled' : ''} ${className}`} style={{ fontSize: size, ...style }} aria-hidden="true">
      {char ?? ''}
    </span>
  );
}
