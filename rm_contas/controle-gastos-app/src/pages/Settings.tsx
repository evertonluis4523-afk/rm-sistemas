import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Seg } from '../components/ui/Seg';
import { Switch } from '../components/ui/Switch';
import { Icon } from '../components/ui/Icon';
import { useSettings, useAuthLock, useToast } from '../contexts';
import { useGoals } from '../hooks/useGoals';
import { db } from '../database/db';
import { ensureSeeded } from '../database/seed';
import { PinManageSheet } from '../components/forms/PinManageSheet';
import type { ThemeMode, FontScale, NotificationPrefs } from '../models';

export function Settings() {
  const navigate = useNavigate();
  const { settings, update } = useSettings();
  const { hasPin, biometricAvailable, biometricEnabled, enableBiometric, disableBiometric } = useAuthLock();
  const { goals } = useGoals();
  const { show } = useToast();
  const [pinSheet, setPinSheet] = useState<null | 'create' | 'change' | 'remove'>(null);

  async function toggleNotification(key: keyof NotificationPrefs) {
    await update({ notifications: { ...settings.notifications, [key]: !settings.notifications[key] } });
  }

  async function handleWipeAll() {
    if (!window.confirm('Isto vai apagar TODOS os seus dados (contas, cartões, lançamentos, metas). Esta ação não pode ser desfeita.\n\nExporte um backup antes, se quiser manter seus dados.')) return;
    await db.transaction('rw', [db.accounts, db.cards, db.categories, db.transactions, db.recurring, db.goals, db.budgets, db.settings, db.history], async () => {
      await Promise.all([db.accounts.clear(), db.cards.clear(), db.categories.clear(), db.transactions.clear(), db.recurring.clear(), db.goals.clear(), db.budgets.clear(), db.settings.clear(), db.history.clear()]);
    });
    await ensureSeeded();
    show('Todos os dados foram apagados');
  }

  return (
    <>
      <PageTopBar title="Configurações" back />
      <main className="view stack">
        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)' }}>Aparência</div>
        <div className="card pad stack">
          <div>
            <div className="dim" style={{ fontSize: 12, fontWeight: 600, marginBottom: 8 }}>Tema</div>
            <Seg options={[{ id: 'auto', label: 'Auto' }, { id: 'light', label: 'Claro' }, { id: 'dark', label: 'Escuro' }]} value={settings.theme} onChange={(v) => update({ theme: v as ThemeMode })} />
          </div>
          <div>
            <div className="dim" style={{ fontSize: 12, fontWeight: 600, marginBottom: 8 }}>Tamanho da fonte</div>
            <Seg options={[{ id: 'sm', label: 'P' }, { id: 'md', label: 'M' }, { id: 'lg', label: 'G' }, { id: 'xl', label: 'GG' }]} value={settings.fontScale} onChange={(v) => update({ fontScale: v as FontScale })} />
          </div>
          <div className="list-item" style={{ border: '1px solid var(--line)', borderRadius: 12, padding: '12px 14px' }}>
            <div className="li-mid">
              <div className="li-t">Alto contraste</div>
              <div className="li-s">Melhora a legibilidade</div>
            </div>
            <Switch on={settings.contrast === 'high'} onClick={() => update({ contrast: settings.contrast === 'high' ? 'normal' : 'high' })} />
          </div>
        </div>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', marginTop: 8 }}>Preferências</div>
        <div className="list">
          <div className="list-item">
            <div className="li-ic"><Icon name="calendar_today" /></div>
            <div className="li-mid">
              <div className="li-t">Primeiro dia do mês</div>
              <div className="li-s">Define o início do ciclo mensal</div>
            </div>
            <select className="input" style={{ width: 70, padding: '8px 10px' }} value={settings.firstDayOfMonth} onChange={(e) => update({ firstDayOfMonth: Number(e.target.value) })}>
              {Array.from({ length: 28 }, (_, i) => i + 1).map((d) => <option key={d} value={d}>{d}</option>)}
            </select>
          </div>
          <div className="list-item">
            <div className="li-ic"><Icon name="flag" /></div>
            <div className="li-mid">
              <div className="li-t">Meta padrão</div>
              <div className="li-s">Destacada no início</div>
            </div>
            <select className="input" style={{ maxWidth: 130, padding: '8px 10px' }} value={settings.defaultGoalId ?? ''} onChange={(e) => update({ defaultGoalId: e.target.value || undefined })}>
              <option value="">Nenhuma</option>
              {goals.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
            </select>
          </div>
          <div className="list-item" onClick={() => navigate('/categorias')} role="button">
            <div className="li-ic"><Icon name="category" /></div>
            <div className="li-mid">
              <div className="li-t">Categorias padrão</div>
              <div className="li-s">Gerenciar categorias</div>
            </div>
            <div className="li-r"><Icon name="chevron_right" /></div>
          </div>
        </div>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', marginTop: 8 }}>Segurança</div>
        <div className="list">
          {hasPin ? (
            <>
              <div className="list-item" onClick={() => setPinSheet('change')} role="button">
                <div className="li-ic"><Icon name="lock_reset" /></div>
                <div className="li-mid"><div className="li-t">Alterar PIN</div></div>
                <div className="li-r"><Icon name="chevron_right" /></div>
              </div>
              <div className="list-item" onClick={() => setPinSheet('remove')} role="button">
                <div className="li-ic"><Icon name="lock_open" /></div>
                <div className="li-mid"><div className="li-t" style={{ color: 'var(--expense)' }}>Remover PIN</div></div>
              </div>
              {biometricAvailable && (
                <div className="list-item">
                  <div className="li-ic"><Icon name="fingerprint" /></div>
                  <div className="li-mid">
                    <div className="li-t">Face ID / biometria</div>
                    <div className="li-s">Desbloqueio rápido pelo aparelho</div>
                  </div>
                  <Switch on={biometricEnabled} onClick={() => (biometricEnabled ? disableBiometric() : enableBiometric())} />
                </div>
              )}
            </>
          ) : (
            <div className="list-item" onClick={() => setPinSheet('create')} role="button">
              <div className="li-ic"><Icon name="lock" /></div>
              <div className="li-mid">
                <div className="li-t">Criar PIN de segurança</div>
                <div className="li-s">Proteja o acesso ao app</div>
              </div>
              <div className="li-r"><Icon name="chevron_right" /></div>
            </div>
          )}
        </div>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', marginTop: 8 }}>Notificações</div>
        <div className="list">
          {([
            ['billDue', 'Conta vencendo'],
            ['goalReached', 'Meta alcançada'],
            ['aboveAverage', 'Gasto acima da média'],
            ['weeklySummary', 'Resumo semanal'],
            ['monthlySummary', 'Resumo mensal'],
          ] as [keyof NotificationPrefs, string][]).map(([key, label]) => (
            <div key={key} className="list-item">
              <div className="li-mid"><div className="li-t">{label}</div></div>
              <Switch on={settings.notifications[key]} onClick={() => toggleNotification(key)} />
            </div>
          ))}
        </div>
        <p className="dim" style={{ fontSize: 11.5, padding: '0 4px' }}>
          As notificações usam a API de notificações do navegador quando o app está instalado; o navegador pode pedir permissão na primeira vez.
        </p>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', marginTop: 8 }}>Dados</div>
        <div className="list">
          <div className="list-item" onClick={() => navigate('/backup')} role="button">
            <div className="li-ic"><Icon name="cloud_upload" /></div>
            <div className="li-mid"><div className="li-t">Backup e sincronização</div></div>
            <div className="li-r"><Icon name="chevron_right" /></div>
          </div>
          <div className="list-item" onClick={() => navigate('/historico')} role="button">
            <div className="li-ic"><Icon name="history" /></div>
            <div className="li-mid"><div className="li-t">Histórico de atividades</div></div>
            <div className="li-r"><Icon name="chevron_right" /></div>
          </div>
          <div className="list-item" onClick={handleWipeAll} role="button">
            <div className="li-ic"><Icon name="delete_forever" style={{ color: 'var(--expense)' }} /></div>
            <div className="li-mid"><div className="li-t" style={{ color: 'var(--expense)' }}>Apagar todos os dados</div></div>
          </div>
        </div>

        <div className="card pad dim center" style={{ fontSize: 12, marginTop: 8 }}>
          Carteira Everton — todos os dados ficam salvos apenas neste aparelho, sem servidor.
        </div>
      </main>

      {pinSheet && <PinManageSheet open={!!pinSheet} mode={pinSheet} onClose={() => setPinSheet(null)} />}
    </>
  );
}
