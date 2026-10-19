import {
  format,
  parseISO,
  addMonths,
  startOfMonth,
  endOfMonth,
  isSameDay,
  isSameMonth,
  differenceInCalendarDays,
  getDaysInMonth,
} from 'date-fns';
import { ptBR } from 'date-fns/locale';

export function ymd(date: Date): string {
  return format(date, 'yyyy-MM-dd');
}

export function monthKey(date: Date): string {
  return format(date, 'yyyy-MM');
}

export function parseYmd(s: string): Date {
  return parseISO(s);
}

export function shiftMonth(key: string, delta: number): string {
  const [y, m] = key.split('-').map(Number);
  return monthKey(addMonths(new Date(y, m - 1, 1), delta));
}

export function monthRange(key: string): { start: Date; end: Date } {
  const [y, m] = key.split('-').map(Number);
  const base = new Date(y, m - 1, 1);
  return { start: startOfMonth(base), end: endOfMonth(base) };
}

export function monthTitle(key: string): string {
  const [y, m] = key.split('-').map(Number);
  const label = format(new Date(y, m - 1, 1), 'MMMM yyyy', { locale: ptBR });
  return label.charAt(0).toUpperCase() + label.slice(1);
}

export function monthAbbrev(key: string): string {
  const [y, m] = key.split('-').map(Number);
  return format(new Date(y, m - 1, 1), 'MMM', { locale: ptBR }).replace('.', '');
}

export function dayHeading(dateStr: string): string {
  const d = parseYmd(dateStr);
  const today = new Date();
  const diff = differenceInCalendarDays(today, d);
  if (diff === 0) return 'Hoje';
  if (diff === 1) return 'Ontem';
  if (diff === -1) return 'Amanhã';
  const weekday = format(d, 'EEE', { locale: ptBR }).replace('.', '');
  return `${weekday}, ${format(d, 'd MMM', { locale: ptBR })}`;
}

export function daysInMonth(key: string): number {
  const [y, m] = key.split('-').map(Number);
  return getDaysInMonth(new Date(y, m - 1, 1));
}

export { isSameDay, isSameMonth };

export const WEEKDAY_ABBR = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
