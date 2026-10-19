import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { useAuthLock, useSettings, useToast } from '../contexts';
import { PinPad } from '../components/ui/PinPad';
import { Icon } from '../components/ui/Icon';
import { Button } from '../components/ui/Button';

type Stage = 'welcome' | 'create' | 'confirm' | 'unlock' | 'forgot';

export function Login() {
  const { hasPin, unlockWithPin, unlockWithBiometric, setupPin, biometricAvailable, biometricEnabled, attemptsLeft, lockedUntil, skipForNoPin } = useAuthLock();
  const { update } = useSettings();
  const { show } = useToast();

  const [stage, setStage] = useState<Stage>(hasPin ? 'unlock' : 'welcome');
  const [firstPin, setFirstPin] = useState('');
  const [error, setError] = useState(false);
  const [remaining, setRemaining] = useState(0);

  useEffect(() => {
    if (hasPin && biometricEnabled) {
      unlockWithBiometric();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!lockedUntil) return;
    const tick = () => setRemaining(Math.max(0, Math.ceil((lockedUntil - Date.now()) / 1000)));
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [lockedUntil]);

  async function handleUnlockAttempt(pin: string) {
    const ok = await unlockWithPin(pin);
    if (!ok) {
      setError(true);
      setTimeout(() => setError(false), 400);
    }
  }

  async function handleCreateFirst(pin: string) {
    setFirstPin(pin);
    setStage('confirm');
  }

  async function handleConfirm(pin: string) {
    if (pin !== firstPin) {
      setError(true);
      setTimeout(() => {
        setError(false);
        setStage('create');
      }, 450);
      return;
    }
    await setupPin(pin);
    await update({ onboarded: true });
    show('PIN criado com sucesso');
  }

  async function handleForgotConfirm() {
    // Sem servidor, não há como recuperar o PIN — apenas removê-lo (dados financeiros permanecem intactos).
    if (window.confirm('Sem um servidor, não é possível recuperar seu PIN. Deseja remover a proteção por PIN? Seus dados financeiros NÃO serão apagados.')) {
      await update({ pinHash: undefined, pinSalt: undefined, biometricEnabled: false, biometricCredentialId: undefined, pinAttempts: 0, pinLockedUntil: undefined });
      skipForNoPin();
      show('PIN removido. Configure um novo em Ajustes quando quiser.');
    }
  }

  return (
    <div style={{ height: '100dvh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 24, gap: 8 }}>
      <div className="row" style={{ flexDirection: 'column', gap: 10, marginBottom: 30 }}>
        <div style={{ width: 64, height: 64, borderRadius: 20, background: 'linear-gradient(135deg, var(--primary), var(--primary-2))', display: 'grid', placeItems: 'center' }}>
          <Icon name="account_balance_wallet" size={30} style={{ color: 'var(--on-primary)' }} />
        </div>
      </div>

      {stage === 'welcome' && (
        <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="center stack" style={{ maxWidth: 320 }}>
          <h1 style={{ fontSize: 22, fontWeight: 800 }}>Bem-vindo à Carteira Everton</h1>
          <p className="muted" style={{ fontSize: 14 }}>Proteja seus dados financeiros com um PIN local. Tudo funciona offline, direto no seu aparelho.</p>
          <div className="stack" style={{ marginTop: 18, width: '100%' }}>
            <Button variant="primary" icon="lock" onClick={() => setStage('create')}>Criar PIN de segurança</Button>
            <Button variant="ghost" onClick={async () => { await update({ onboarded: true }); skipForNoPin(); }}>Usar sem PIN por enquanto</Button>
          </div>
        </motion.div>
      )}

      {stage === 'create' && (
        <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="center stack">
          <h1 style={{ fontSize: 19, fontWeight: 800 }}>Crie um PIN de 4 dígitos</h1>
          <PinPad onComplete={handleCreateFirst} error={error} />
        </motion.div>
      )}

      {stage === 'confirm' && (
        <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="center stack">
          <h1 style={{ fontSize: 19, fontWeight: 800 }}>Confirme seu PIN</h1>
          <PinPad onComplete={handleConfirm} error={error} />
        </motion.div>
      )}

      {stage === 'unlock' && (
        <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="center stack">
          <h1 style={{ fontSize: 19, fontWeight: 800 }}>Digite seu PIN</h1>
          {lockedUntil ? (
            <p style={{ color: 'var(--expense)', fontSize: 13.5 }}>Muitas tentativas. Tente novamente em {remaining}s.</p>
          ) : (
            <p className="muted" style={{ fontSize: 12.5 }}>{attemptsLeft} tentativa(s) restante(s)</p>
          )}
          <PinPad onComplete={handleUnlockAttempt} error={error} disabled={!!lockedUntil} />
          {biometricAvailable && biometricEnabled && (
            <Button variant="ghost" icon="fingerprint" onClick={() => unlockWithBiometric()} style={{ marginTop: 10, width: 'auto' }}>
              Usar biometria
            </Button>
          )}
          <button className="dim" style={{ fontSize: 12.5, marginTop: 18, textDecoration: 'underline' }} onClick={handleForgotConfirm}>
            Esqueci meu PIN
          </button>
        </motion.div>
      )}
    </div>
  );
}
