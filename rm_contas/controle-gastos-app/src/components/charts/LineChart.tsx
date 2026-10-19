import '../charts/chartSetup';
import { Line } from 'react-chartjs-2';
import { formatMoney } from '../../utils/currency';

export function LineChart({ labels, values, color = '#FF8A00' }: { labels: (string | number)[]; values: number[]; color?: string }) {
  const data = {
    labels,
    datasets: [
      {
        data: values,
        borderColor: color,
        backgroundColor: (ctx: { chart: { ctx: CanvasRenderingContext2D; chartArea?: { top: number; bottom: number } } }) => {
          const { chart } = ctx;
          const { chartArea } = chart;
          if (!chartArea) return color + '22';
          const gradient = chart.ctx.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
          gradient.addColorStop(0, color + '55');
          gradient.addColorStop(1, color + '00');
          return gradient;
        },
        fill: true,
        tension: 0.35,
        pointRadius: 0,
        pointHoverRadius: 5,
        pointHoverBackgroundColor: color,
        borderWidth: 2.5,
      },
    ],
  };

  return (
    <div style={{ height: 150 }}>
      <Line
        data={data}
        options={{
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false },
            tooltip: { callbacks: { label: (ctx) => formatMoney(Number(ctx.raw)) } },
          },
          scales: {
            x: { grid: { display: false }, ticks: { color: '#6E7480', font: { size: 10 }, maxTicksLimit: 6 } },
            y: { display: false },
          },
        }}
      />
    </div>
  );
}
