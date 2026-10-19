interface ProgressBarProps {
  value: number; // 0-100
  tone?: 'primary' | 'income' | 'warn' | 'over';
}

export function ProgressBar({ value, tone = 'primary' }: ProgressBarProps) {
  const pct = Math.min(100, Math.max(0, value));
  const cls = tone === 'primary' ? '' : tone;
  return (
    <div className={`progress ${cls}`}>
      <span style={{ width: `${pct}%` }} />
    </div>
  );
}
