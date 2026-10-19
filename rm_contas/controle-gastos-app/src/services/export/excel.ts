import type { ReportRow, ReportMeta } from './types';

/** ExcelJS é carregado sob demanda (code-split) para manter o pacote inicial leve. */
export async function exportReportExcel(rows: ReportRow[], meta: ReportMeta): Promise<Blob> {
  const { default: ExcelJS } = await import('exceljs');
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'Carteira Everton';
  workbook.created = new Date(meta.generatedAt);

  const sheet = workbook.addWorksheet('Lançamentos', { views: [{ state: 'frozen', ySplit: 1 }] });

  sheet.columns = [
    { header: 'Data', key: 'date', width: 14 },
    { header: 'Tipo', key: 'type', width: 12 },
    { header: 'Descrição', key: 'description', width: 32 },
    { header: 'Categoria', key: 'category', width: 20 },
    { header: 'Conta', key: 'account', width: 18 },
    { header: 'Pagamento', key: 'method', width: 16 },
    { header: 'Valor (R$)', key: 'amount', width: 16 },
  ];

  sheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF14161B' } };
    cell.alignment = { vertical: 'middle' };
  });

  rows.forEach((r) => {
    const row = sheet.addRow({
      date: new Date(r.date + 'T00:00:00').toLocaleDateString('pt-BR'),
      type: r.type === 'income' ? 'Receita' : 'Despesa',
      description: r.description,
      category: r.category,
      account: r.account,
      method: r.method,
      amount: r.amount / 100,
    });
    const amountCell = row.getCell('amount');
    amountCell.numFmt = '"R$" #,##0.00';
    amountCell.font = { color: { argb: r.type === 'income' ? 'FF2ECC71' : 'FFFF5C5C' }, bold: true };
  });

  const summary = workbook.addWorksheet('Resumo');
  summary.columns = [{ header: 'Indicador', key: 'k', width: 24 }, { header: 'Valor', key: 'v', width: 20 }];
  summary.getRow(1).font = { bold: true };
  summary.addRow({ k: 'Período', v: meta.periodLabel });
  summary.addRow({ k: 'Receitas', v: meta.totalIncome / 100 }).getCell('v').numFmt = '"R$" #,##0.00';
  summary.addRow({ k: 'Despesas', v: meta.totalExpense / 100 }).getCell('v').numFmt = '"R$" #,##0.00';
  summary.addRow({ k: 'Saldo', v: (meta.totalIncome - meta.totalExpense) / 100 }).getCell('v').numFmt = '"R$" #,##0.00';

  const buffer = await workbook.xlsx.writeBuffer();
  return new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
}
