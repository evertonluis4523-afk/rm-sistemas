import { useLiveQuery } from 'dexie-react-hooks';
import { PageTopBar } from '../components/layout/PageTopBar';
import { EmptyState } from '../components/ui/EmptyState';
import { Icon } from '../components/ui/Icon';
import { db } from '../database/db';

const ACTION_ICON: Record<string, string> = { create: 'add_circle', update: 'edit', delete: 'delete' };
const ACTION_COLOR: Record<string, string> = { create: 'var(--income)', update: 'var(--info)', delete: 'var(--expense)' };

export function History() {
  const logs = useLiveQuery(() => db.history.orderBy('timestamp').reverse().limit(200).toArray(), []);

  return (
    <>
      <PageTopBar title="Histórico" back />
      <main className="view">
        {!logs || logs.length === 0 ? (
          <EmptyState icon="history" title="Nenhuma atividade ainda" subtitle="Toda inclusão, edição e exclusão aparecerá aqui." />
        ) : (
          <div className="list">
            {logs.map((log) => (
              <div key={log.id} className="list-item">
                <span className="avatar" style={{ background: 'var(--surface-2)', color: ACTION_COLOR[log.action] }}>
                  <Icon name={ACTION_ICON[log.action]} size={18} />
                </span>
                <div className="li-mid">
                  <div className="li-t">{log.summary}</div>
                  <div className="li-s">{new Date(log.timestamp).toLocaleString('pt-BR')}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </>
  );
}
