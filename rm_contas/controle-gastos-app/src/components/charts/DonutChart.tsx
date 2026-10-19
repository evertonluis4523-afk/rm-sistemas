import '../charts/chartSetup';
import { Doughnut } from 'react-chartjs-2';
import { formatMoney, formatMoneyShort } from '../../utils/currency';

interface DonutSlice {
  label: string;
  value: number;
  color: string;
}

export function DonutChart({ slices, centerLabel }: { slices: DonutSlice[]; centerLabel?: string }) {
  const total = slices.reduce((s, x) => s + x.value, 0);

  const data = {
    labels: slices.map((s) => s.label),
    datasets: [
      {
        data: slices.map((s) => s.value),
        backgroundColor: slices.map((s) => s.color),
        borderWidth: 0,
        borderRadius: 4,
        spacing: 2,
      },
    ],
  };

  return (
    <div style={{ position: 'relative', width: 168, height: 168, flex: '0 0 auto', margin: '0 auto' }}>
      <Doughnut
        data={data}
        options={{
          cutout: '68%',
          plugins: {
            tooltip: { callbacks: { label: (ctx) => `${ctx.label}: ${formatMoney(Number(ctx.raw))}` } },
          },
          maintainAspectRatio: true,
        }}
      />
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeContent: 'center', textAlign: 'center' }}>
        <div style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 600 }}>{centerLabel ?? `${slices.length} categorias`}</div>
        <div style={{ fontSize: 19, fontWeight: 800, fontFamily: 'var(--font-mono)' }}>{formatMoneyShort(total)}</div>
      </div>
    </div>
  );
}
