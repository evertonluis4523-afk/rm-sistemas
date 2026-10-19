const formatters = new Map<string, Intl.NumberFormat>();

function getFormatter(currency: string, locale = 'pt-BR'): Intl.NumberFormat {
  const key = `${locale}:${currency}`;
  let f = formatters.get(key);
  if (!f) {
    f = new Intl.NumberFormat(locale, { style: 'currency', currency });
    formatters.set(key, f);
  }
  return f;
}

/** Formata centavos para moeda (ex.: 189000 -> "R$ 1.890,00"). */
export function formatMoney(cents: number, currency = 'BRL'): string {
  return getFormatter(currency).format((cents || 0) / 100);
}

/** Versão compacta para eixos de gráfico (ex.: 1890000 -> "R$ 18,9k"). */
export function formatMoneyShort(cents: number, currency = 'BRL'): string {
  const v = (cents || 0) / 100;
  const abs = Math.abs(v);
  const symbol = currency === 'BRL' ? 'R$' : currency;
  if (abs >= 1_000_000) return `${symbol} ${(v / 1_000_000).toFixed(1).replace('.', ',')}M`;
  if (abs >= 1000) return `${symbol} ${(v / 1000).toFixed(v % 1000 === 0 ? 0 : 1).replace('.', ',')}k`;
  return `${symbol} ${v.toFixed(0)}`;
}

/** Converte texto digitado (formatos livres pt-BR/en) em centavos inteiros. */
export function parseMoney(input: string | number): number {
  if (typeof input === 'number') return Math.round(input * 100);
  if (!input) return 0;
  let s = String(input).replace(/[^\d.,-]/g, '').trim();
  if (!s) return 0;
  const isNegative = s.startsWith('-');
  s = s.replace('-', '');
  if (s.includes(',') && s.includes('.')) {
    s = s.replace(/\./g, '').replace(',', '.');
  } else if (s.includes(',')) {
    s = s.replace(',', '.');
  }
  const n = parseFloat(s);
  if (Number.isNaN(n)) return 0;
  const cents = Math.round(n * 100);
  return isNegative ? -cents : cents;
}
