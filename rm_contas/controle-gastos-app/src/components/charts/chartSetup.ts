import {
  Chart as ChartJS,
  ArcElement,
  LineElement,
  BarElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Tooltip,
  Filler,
} from 'chart.js';

ChartJS.register(ArcElement, LineElement, BarElement, PointElement, CategoryScale, LinearScale, Tooltip, Filler);

ChartJS.defaults.font.family = "'Inter', system-ui, sans-serif";
ChartJS.defaults.color = '#A7ADB8';
ChartJS.defaults.plugins.tooltip.backgroundColor = '#1A1D22';
ChartJS.defaults.plugins.tooltip.titleColor = '#FFFFFF';
ChartJS.defaults.plugins.tooltip.bodyColor = '#FFFFFF';
ChartJS.defaults.plugins.tooltip.borderColor = '#2A2D34';
ChartJS.defaults.plugins.tooltip.borderWidth = 1;
ChartJS.defaults.plugins.tooltip.padding = 10;
ChartJS.defaults.plugins.tooltip.cornerRadius = 10;
ChartJS.defaults.plugins.tooltip.displayColors = false;
