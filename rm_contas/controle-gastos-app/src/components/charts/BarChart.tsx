import '../charts/chartSetup';
import { Bar } from 'react-chartjs-2';
import { formatMoney } from '../../utils/currency';

interface BarSeries {
  labels: string[];
  values: number[];
  highlightIndex?: number;
}

export function BarChart({ labels, values, highlightIndex }: BarSeries) {
  const data = {
    labels,
    datasets: [
      {
        data: values,
        backgroundColor: labels.map((_, i) => (i === highlightIndex ? '#FF8A00' : '#3a3d44')),
        borderRadius: 6,
        maxBarThickness: 34,
      },
    ],
  };

  return (
    <div style={{ height: 180 }}>
      <Bar
        data={data}
        options={{
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false },
            tooltip: { callbacks: { label: (ctx) => formatMoney(Number(ctx.raw)) } },
          },
          scales: {
            x: { grid: { display: false }, ticks: { color: '#6E7480', font: { size: 10.5 } } },
            y: { display: false },
          },
        }}
      />
    </div>
  );
}
