import { useRef, useState } from 'react';
import { PageTopBar } from '../components/layout/PageTopBar';
import { Icon } from '../components/ui/Icon';
import { Button } from '../components/ui/Button';
import { Switch } from '../components/ui/Switch';
import { Input } from '../components/ui/Input';
import { useToast } from '../contexts';
import { exportBackup, importBackup } from '../services/backup';
import { shareOrDownload } from '../utils/download';
import { ymd } from '../utils/date';

export function Backup() {
  const { show } = useToast();
  const [protect, setProtect] = useState(false);
  const [password, setPassword] = useState('');
  const [importPassword, setImportPassword] = useState('');
  const [pendingImportFile, setPendingImportFile] = useState<File | null>(null);
  const [needsPassword, setNeedsPassword] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  async function handleExport() {
    if (protect && password.length < 4) return show('A senha deve ter ao menos 4 caracteres');
    const blob = await exportBackup(protect ? password : undefined);
    await shareOrDownload(blob, `carteira-everton-backup-${ymd(new Date())}.json`, 'Backup Carteira Everton');
    show('Backup exportado');
  }

  async function handleFileChosen(file: File) {
    const text = await file.text();
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return show('Arquivo inválido');
    }
    if (parsed && typeof parsed === 'object' && (parsed as { encrypted?: boolean }).encrypted) {
      setPendingImportFile(file);
      setNeedsPassword(true);
      return;
    }
    const result = await importBackup(text);
    if (result.ok) show('Backup importado com sucesso');
    else show(result.error);
  }

  async function handleImportWithPassword() {
    if (!pendingImportFile) return;
    const text = await pendingImportFile.text();
    const result = await importBackup(text, importPassword);
    if (result.ok) {
      show('Backup importado com sucesso');
      setNeedsPassword(false);
      setPendingImportFile(null);
      setImportPassword('');
    } else {
      show(result.error);
    }
  }

  return (
    <>
      <PageTopBar title="Backup" back />
      <main className="view stack">
        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)' }}>Exportar backup</div>
        <div className="card pad stack">
          <p className="dim" style={{ fontSize: 13, margin: 0 }}>Gera um arquivo .json com todos os seus dados: contas, cartões, categorias, lançamentos, metas e orçamentos.</p>
          <div className="list-item" style={{ border: '1px solid var(--line)', borderRadius: 12, padding: '12px 14px' }}>
            <div className="li-mid">
              <div className="li-t">Proteger com senha</div>
              <div className="li-s">Criptografa o arquivo com AES-256</div>
            </div>
            <Switch on={protect} onClick={() => setProtect((v) => !v)} ariaLabel="Proteger com senha" />
          </div>
          {protect && <Input type="password" placeholder="Senha do backup (mín. 4 caracteres)" value={password} onChange={(e) => setPassword(e.target.value)} />}
          <Button variant="primary" icon="cloud_download" onClick={handleExport}>Exportar backup</Button>
        </div>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', marginTop: 8 }}>Importar backup</div>
        <div className="card pad stack">
          <p className="dim" style={{ fontSize: 13, margin: 0 }}>
            <b style={{ color: 'var(--expense)' }}>Atenção:</b> importar um backup substitui todos os dados atuais do app.
          </p>
          <Button variant="secondary" icon="upload_file" onClick={() => fileRef.current?.click()}>Escolher arquivo</Button>
          <input ref={fileRef} type="file" accept="application/json,.json" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileChosen(f); }} />

          {needsPassword && (
            <div className="stack" style={{ marginTop: 6 }}>
              <Input type="password" placeholder="Senha do backup" value={importPassword} onChange={(e) => setImportPassword(e.target.value)} />
              <Button variant="primary" onClick={handleImportWithPassword}>Desbloquear e importar</Button>
            </div>
          )}
        </div>

        <div className="section-title" style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--text-2)', marginTop: 8 }}>Sincronização em nuvem</div>
        <div className="card pad row" style={{ gap: 12 }}>
          <span className="avatar" style={{ background: 'var(--surface-2)' }}>
            <Icon name="cloud_off" style={{ color: 'var(--text-3)' }} />
          </span>
          <div>
            <div style={{ fontWeight: 700, fontSize: 14 }}>Nenhum provedor conectado</div>
            <div className="dim" style={{ fontSize: 12.5 }}>A estrutura de sincronização já está pronta no app — conecte um provedor (como Supabase ou Firebase) em uma atualização futura para sincronizar entre aparelhos.</div>
          </div>
        </div>
      </main>
    </>
  );
}
