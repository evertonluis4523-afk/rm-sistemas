import { useMemo, useState } from 'react';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Card } from '../components/ui/Card';
import { Seg } from '../components/ui/Seg';
import { Button } from '../components/ui/Button';
import { EmptyState } from '../components/ui/EmptyState';
import { DonutChart } from '../components/charts/DonutChart';
import { BarChart } from '../components/charts/BarChart';
import { useMonth, useToast } from '../contexts';
import { useAllTransactions } from '../hooks/useTransactions';
import { useCategoryMap } from '../hooks/useCategories';
import { useAccounts } from '../hooks/useAccounts';
import { formatMoney } from '../utils/currency';
import { monthTitle, monthAbbrev, ymd, isSameDay } from '../utils/date';
import { PAYMENT_METHODS, type Transaction } from '../models';
import { exportReportPdf } from '../services/export/pdf';
import { exportReportExcel } from '../services/export/excel';
import { exportReportCsv } from '../services/export/csv';
import { shareOrDownload } from '../utils/download';
import type { ReportRow } from '../services/export/types';

type Period = 'day' | 'week' | 'month' | 'year' | 'custom';

export function Reports() {
  const { month } = useMonth();
  const { transactions: all } = useAllTransactions();
  const catMap = useCategoryMap();
  const { accounts } = useAccounts();
  const { show } = useToast();

  const [period, setPeriod] = useState<Period>('month');
  const [customStart, setCustomStart] = useState(ymd(new Date()));
  const [customEnd, setCustomEnd] = useState(ymd(new Date()));

  const { rows, periodLabel } = useMemo(() => {
    const now = new Date();
    let filtered: Transaction[] = [];
    let label = '';

    if (period === 'day') {
      filtered = all.filter((t) => isSameDay(new Date(t.date + 'T00:00:00'), now));
      label = now.toLocaleDateString('pt-BR');
    } else if (period === 'week') {
      filtered = all.filter((t) => Math.abs((now.getTime() - new Date(t.date + 'T00:00:00').getTime()) / 86_400_000) <= 7);
      label = 'Últimos 7 dias';
    } else if (period === 'month') {
      filtered = all.filter((t) => t.date.slice(0, 7) === month);
      label = monthTitle(month);
    } else if (period === 'year') {
      const year = month.slice(0, 4);
      filtered = all.filter((t) => t.date.slice(0, 4) === year);
      label = year;
    } else {
      filtered = all.filter((t) => t.date >= customStart && t.date <= customEnd);
      label = `${new Date(customStart + 'T00:00:00').toLocaleDateString('pt-BR')} a ${new Date(customEnd + 'T00:00:00').toLocaleDateString('pt-BR')}`;
    }

    return { rows: filtered.sort((a, b) => b.date.localeCompare(a.date)), periodLabel: label };
  }, [all, period, month, customStart, customEnd]);

  const income = rows.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const expense = rows.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

  const byCategory = useMemo(() => {
    const map = new Map<string, number>();
    rows.filter((t) => t.type === 'expense').forEach((t) => map.set(t.categoryId, (map.get(t.categoryId) || 0) + t.amount));
    return [...map.entries()].map(([catId, amount]) => ({ catId, amount })).sort((a, b) => b.amount - a.amount);
  }, [rows]);

  const monthlyBars = useMemo(() => {
    if (period !== 'year') return null;
    const year = month.slice(0, 4);
    const totals = Array.from({ length: 12 }, (_, i) => {
      const key = `${year}-${String(i + 1).padStart(2, '0')}`;
      return all.filter((t) => t.type === 'expense' && t.date.slice(0, 7) === key).reduce((s, t) => s + t.amount, 0);
    });
    return { labels: Array.from({ length: 12 }, (_, i) => monthAbbrev(`${year}-${String(i + 1).padStart(2, '0')}`)), values: totals };
  }, [all, period, month]);

  const topExpenses = [...rows].filter((t) => t.type === 'expense').sort((a, b) => b.amount - a.amount).slice(0, 8);

  function buildExportData(): { rows: ReportRow[]; meta: { title: string; periodLabel: string; totalIncome: number; totalExpense: number; generatedAt: number } } {
    const exportRows: ReportRow[] = rows.map((t) => ({
      date: t.date,
      description: t.description || catMap.get(t.categoryId)?.name || '',
      category: catMap.get(t.categoryId)?.name || '—',
      account: accounts.find((a) => a.id === t.accountId)?.name || '—',
      method: PAYMENT_METHODS.find((m) => m.id === t.method)?.name || t.method,
      type: t.type,
      amount: t.amount,
    }));
    return { rows: exportRows, meta: { title: 'Relatório financeiro', periodLabel, totalIncome: income, totalExpense: expense, generatedAt: Date.now() } };
  }

  async function handleExport(format: 'pdf' | 'excel' | 'csv') {
    if (rows.length === 0) return show('Nada para exportar neste período');
    const { rows: exportRows, meta } = buildExportData();
    if (format === 'pdf') {
      const blob = await exportReportPdf(exportRows, meta);
      await shareOrDownload(blob, `carteira-everton-${period}.pdf`, meta.title);
    } else if (format === 'excel') {
      const blob = await exportReportExcel(exportRows, meta);
      await shareOrDownload(blob, `carteira-everton-${period}.xlsx`, meta.title);
    } else {
      const blob = exportReportCsv(exportRows);
      await shareOrDownload(blob, `carteira-everton-${period}.csv`, meta.title);
    }
  }

  return (
    <>
      <PageTopBar title="Relatórios" back />
      <main className="view stack">
        <Seg
          options={[
            { id: 'day', label: 'Dia' }, { id: 'week', label: 'Semana' }, { id: 'month', label: 'Mês' },
            { id: 'year', label: 'Ano' }, { id: 'custom', label: 'Personalizado' },
          ]}
          value={period}
          onChange={(v) => setPeriod(v as Period)}
        />

        {period === 'custom' && (
          <div className="row" style={{ gap: 8 }}>
            <input type="date" className="input" value={customStart} onChange={(e) => setCustomStart(e.target.value)} />
            <input type="date" className="input" value={customEnd} onChange={(e) => setCustomEnd(e.target.value)} />
          </div>
        )}

        <Card elevated>
          <div className="dim" style={{ fontSize: 12, fontWeight: 600 }}>{periodLabel}</div>
          <div className="row" style={{ gap: 18, marginTop: 6 }}>
            <div>
              <div className="dim" style={{ fontSize: 11 }}>Receitas</div>
              <div className="mono" style={{ fontWeight: 800, fontSize: 18, color: 'var(--income)' }}>{formatMoney(income)}</div>
            </div>
            <div>
              <div className="dim" style={{ fontSize: 11 }}>Despesas</div>
              <div className="mono" style={{ fontWeight: 800, fontSize: 18 }}>{formatMoney(expense)}</div>
            </div>
            <div>
              <div className="dim" style={{ fontSize: 11 }}>Saldo</div>
              <div className="mono" style={{ fontWeight: 800, fontSize: 18, color: income - expense >= 0 ? 'var(--income)' : 'var(--expense)' }}>{formatMoney(income - expense)}</div>
            </div>
          </div>
        </Card>

        {monthlyBars && (
          <>
            <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', margin: '4px 2px' }}>Despesas por mês</div>
            <Card>
              <BarChart labels={monthlyBars.labels} values={monthlyBars.values} highlightIndex={new Date().getMonth()} />
            </Card>
          </>
        )}

        {byCategory.length > 0 ? (
          <>
            <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', margin: '4px 2px' }}>Distribuição por categoria</div>
            <Card>
              <DonutChart slices={byCategory.slice(0, 8).map((c) => ({ label: catMap.get(c.catId)?.name ?? '—', value: c.amount, color: catMap.get(c.catId)?.color ?? '#8E95A2' }))} />
            </Card>
          </>
        ) : (
          <EmptyState icon="bar_chart" title="Sem dados neste período" subtitle="Registre lançamentos para gerar relatórios." />
        )}

        {topExpenses.length > 0 && (
          <>
            <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', margin: '4px 2px' }}>Maiores gastos</div>
            <div className="list">
              {topExpenses.map((t) => {
                const cat = catMap.get(t.categoryId);
                return (
                  <div key={t.id} className="list-item">
                    <span className="avatar" style={{ background: (cat?.color ?? '#8E95A2') + '26', color: cat?.color }}>
                      <span className="msr">{cat?.icon ?? 'category'}</span>
                    </span>
                    <div className="li-mid">
                      <div className="li-t">{t.description || cat?.name}</div>
                      <div className="li-s">{new Date(t.date + 'T00:00:00').toLocaleDateString('pt-BR')} · {cat?.name}</div>
                    </div>
                    <div className="mono" style={{ fontWeight: 700 }}>{formatMoney(t.amount)}</div>
                  </div>
                );
              })}
            </div>
          </>
        )}

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', margin: '4px 2px' }}>Exportar</div>
        <div className="row" style={{ gap: 8 }}>
          <Button variant="secondary" icon="picture_as_pdf" onClick={() => handleExport('pdf')}>PDF</Button>
          <Button variant="secondary" icon="table_chart" onClick={() => handleExport('excel')}>Excel</Button>
          <Button variant="secondary" icon="description" onClick={() => handleExport('csv')}>CSV</Button>
        </div>
      </main>
    </>
  );
}
