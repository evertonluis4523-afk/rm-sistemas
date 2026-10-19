/** Anel SVG da pontuação de saúde financeira (estilo Orange Finance). */
export function ScoreRing({ score, color, label }: { score: number; color: string; label: string }) {
  const r = 52;
  const c = 2 * Math.PI * r;
  const filled = (score / 100) * c;
  return (
    <div style={{ position: 'relative', width: 128, height: 128, flex: '0 0 auto' }}>
      <svg width="128" height="128" viewBox="0 0 128 128">
        <circle cx="64" cy="64" r={r} fill="none" stroke="var(--surface-2)" strokeWidth="12" />
        <circle
          cx="64"
          cy="64"
          r={r}
          fill="none"
          stroke={color}
          strokeWidth="12"
          strokeLinecap="round"
          strokeDasharray={`${filled} ${c - filled}`}
          transform="rotate(-90 64 64)"
          style={{ transition: 'stroke-dasharray 0.8s ease' }}
        />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <strong style={{ fontSize: '1.6rem', fontWeight: 800 }}>{score}</strong>
        <span style={{ fontSize: 12, fontWeight: 700, color }}>{label}</span>
      </div>
    </div>
  );
}
