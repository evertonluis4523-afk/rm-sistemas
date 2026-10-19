import type { ReportRow } from './types';

function escapeCsv(value: string): string {
  if (/[",\n;]/.test(value)) return `"${value.replace(/"/g, '""')}"`;
  return value;
}

export function exportReportCsv(rows: ReportRow[]): Blob {
  const header = ['Data', 'Tipo', 'Descrição', 'Categoria', 'Conta', 'Pagamento', 'Valor'];
  const lines = [header.join(';')];
  rows.forEach((r) => {
    lines.push(
      [
        new Date(r.date + 'T00:00:00').toLocaleDateString('pt-BR'),
        r.type === 'income' ? 'Receita' : 'Despesa',
        escapeCsv(r.description),
        escapeCsv(r.category),
        escapeCsv(r.account),
        escapeCsv(r.method),
        (r.amount / 100).toFixed(2).replace('.', ','),
      ].join(';')
    );
  });
  return new Blob(['﻿' + lines.join('\n')], { type: 'text/csv;charset=utf-8' });
}
