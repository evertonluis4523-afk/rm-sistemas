import { useNavigate } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Card } from '../components/ui/Card';
import { Icon } from '../components/ui/Icon';
import { db } from '../database/db';

const ITEMS = [
  { to: '/relatorios', icon: 'bar_chart', label: 'Relatórios', desc: 'PDF, Excel, CSV e gráficos' },
  { to: '/calendario', icon: 'calendar_month', label: 'Calendário', desc: 'Contas e eventos do mês' },
  { to: '/metas', icon: 'flag', label: 'Metas', desc: 'Viagem, casa, reserva...' },
  { to: '/orcamentos', icon: 'savings', label: 'Planejamento', desc: 'Limites mensais por categoria' },
  { to: '/categorias', icon: 'category', label: 'Categorias', desc: 'Personalize ícones e cores' },
  { to: '/busca', icon: 'search', label: 'Buscar', desc: 'Encontre qualquer lançamento' },
  { to: '/backup', icon: 'cloud_upload', label: 'Backup', desc: 'Exportar e importar dados' },
  { to: '/configuracoes', icon: 'settings', label: 'Configurações', desc: 'PIN, Face ID, tema e mais' },
];

export function More() {
  const navigate = useNavigate();
  const history = useLiveQuery(() => db.history.orderBy('timestamp').reverse().limit(8).toArray(), []);

  return (
    <>
      <PageTopBar title="Mais" />
      <main className="view stack">
        <Card pad={false} style={{ padding: '6px 16px' }}>
          {ITEMS.map((i) => (
            <div key={i.to} className="list-item" onClick={() => navigate(i.to)} role="button" style={{ cursor: 'pointer', gap: 13 }}>
              <span style={{ width: 42, height: 42, borderRadius: 14, display: 'grid', placeItems: 'center', flexShrink: 0, background: 'var(--primary-soft)' }}>
                <Icon name={i.icon} style={{ color: 'var(--primary)' }} />
              </span>
              <div className="li-mid">
                <div className="li-t">{i.label}</div>
                <div className="li-s">{i.desc}</div>
              </div>
              <Icon name="chevron_right" style={{ color: 'var(--text-3)' }} />
            </div>
          ))}
        </Card>

        {history && history.length > 0 && (
          <Card pad={false} style={{ padding: '16px 16px 6px' }}>
            <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Histórico recente</h2>
            {history.map((h) => (
              <div className="list-item" key={h.id} style={{ gap: 11 }}>
                <Icon name="history" size={18} style={{ color: 'var(--text-3)' }} />
                <div className="li-mid">
                  <div style={{ fontSize: 13 }}>{h.summary}</div>
                  <div className="li-s">{new Date(h.timestamp).toLocaleDateString('pt-BR')}</div>
                </div>
              </div>
            ))}
          </Card>
        )}

        <div className="dim center" style={{ fontSize: 12, padding: '4px 8px' }}>
          <b style={{ color: 'var(--text)' }}>Carteira Everton</b> · 100% offline, dados só neste aparelho.
        </div>
      </main>
    </>
  );
}
