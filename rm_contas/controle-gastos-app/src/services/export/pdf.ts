import { formatMoney } from '../../utils/currency';
import type { ReportRow, ReportMeta } from './types';

const ORANGE: [number, number, number] = [255, 138, 0];
const INK: [number, number, number] = [20, 22, 27];
const MUTED: [number, number, number] = [110, 116, 128];

/** jsPDF/autoTable são carregados sob demanda (code-split) para manter o pacote inicial leve. */
export async function exportReportPdf(rows: ReportRow[], meta: ReportMeta): Promise<Blob> {
  const [{ jsPDF }, { default: autoTable }] = await Promise.all([import('jspdf'), import('jspdf-autotable')]);
  const doc = new jsPDF({ unit: 'pt', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();

  doc.setFillColor(...ORANGE);
  doc.rect(0, 0, pageWidth, 70, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(18);
  doc.text('Carteira Everton', 40, 34);
  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text(meta.title, 40, 52);

  doc.setTextColor(...INK);
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(`Período: ${meta.periodLabel}`, 40, 92);
  doc.text(`Gerado em: ${new Date(meta.generatedAt).toLocaleString('pt-BR')}`, 40, 106);

  doc.setFontSize(11);
  doc.setTextColor(...MUTED);
  doc.text('Receitas', 40, 130);
  doc.text('Despesas', 200, 130);
  doc.text('Saldo', 360, 130);
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(46, 204, 113);
  doc.text(formatMoney(meta.totalIncome), 40, 148);
  doc.setTextColor(255, 92, 92);
  doc.text(formatMoney(meta.totalExpense), 200, 148);
  const balance = meta.totalIncome - meta.totalExpense;
  const balanceColor: [number, number, number] = balance >= 0 ? [46, 204, 113] : [255, 92, 92];
  doc.setTextColor(...balanceColor);
  doc.text(formatMoney(balance), 360, 148);

  autoTable(doc, {
    startY: 172,
    head: [['Data', 'Descrição', 'Categoria', 'Conta', 'Pagamento', 'Valor']],
    body: rows.map((r) => [
      new Date(r.date + 'T00:00:00').toLocaleDateString('pt-BR'),
      r.description,
      r.category,
      r.account,
      r.method,
      (r.type === 'expense' ? '-' : '+') + formatMoney(r.amount),
    ]),
    headStyles: { fillColor: INK, textColor: 255, fontSize: 9 },
    bodyStyles: { fontSize: 9, textColor: INK },
    alternateRowStyles: { fillColor: [246, 247, 249] },
    columnStyles: { 5: { halign: 'right', fontStyle: 'bold' } },
    margin: { left: 40, right: 40 },
  });

  return doc.output('blob');
}
