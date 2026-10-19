import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { useSettings } from './SettingsContext';
import { hashPin, verifyPin, MAX_PIN_ATTEMPTS, LOCKOUT_MS } from '../services/auth/pin';
import { registerBiometric, verifyBiometric, isPlatformAuthenticatorAvailable } from '../services/auth/webauthn';

const AUTO_LOCK_AFTER_MS = 5 * 60_000; // re-trava após 5min em segundo plano

interface AuthLockContextValue {
  hasPin: boolean;
  locked: boolean;
  biometricEnabled: boolean;
  biometricAvailable: boolean;
  attemptsLeft: number;
  lockedUntil: number | null;
  unlockWithPin: (pin: string) => Promise<boolean>;
  unlockWithBiometric: () => Promise<boolean>;
  setupPin: (pin: string) => Promise<void>;
  changePin: (currentPin: string, newPin: string) => Promise<boolean>;
  removePin: (currentPin: string) => Promise<boolean>;
  enableBiometric: () => Promise<boolean>;
  disableBiometric: () => Promise<void>;
  lockNow: () => void;
  skipForNoPin: () => void;
}

const AuthLockContext = createContext<AuthLockContextValue | null>(null);

export function AuthLockProvider({ children }: { children: ReactNode }) {
  const { settings, update } = useSettings();
  const hasPin = !!settings.pinHash;
  const [locked, setLocked] = useState(hasPin);
  const [biometricAvailable, setBiometricAvailable] = useState(false);
  const hiddenAt = useRef<number | null>(null);

  useEffect(() => {
    isPlatformAuthenticatorAvailable().then(setBiometricAvailable);
  }, []);

  useEffect(() => {
    setLocked(hasPin);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasPin]);

  useEffect(() => {
    function onVisibility() {
      if (document.hidden) {
        hiddenAt.current = Date.now();
      } else if (hiddenAt.current && hasPin) {
        const elapsed = Date.now() - hiddenAt.current;
        if (elapsed > AUTO_LOCK_AFTER_MS) setLocked(true);
        hiddenAt.current = null;
      }
    }
    document.addEventListener('visibilitychange', onVisibility);
    return () => document.removeEventListener('visibilitychange', onVisibility);
  }, [hasPin]);

  const attemptsLeft = Math.max(0, MAX_PIN_ATTEMPTS - (settings.pinAttempts || 0));
  const lockedUntil = settings.pinLockedUntil && settings.pinLockedUntil > Date.now() ? settings.pinLockedUntil : null;

  async function unlockWithPin(pin: string): Promise<boolean> {
    if (lockedUntil) return false;
    if (!settings.pinHash || !settings.pinSalt) return false;
    const ok = await verifyPin(pin, settings.pinHash, settings.pinSalt);
    if (ok) {
      await update({ pinAttempts: 0, pinLockedUntil: undefined });
      setLocked(false);
      return true;
    }
    const nextAttempts = (settings.pinAttempts || 0) + 1;
    const patch: Partial<typeof settings> = { pinAttempts: nextAttempts };
    if (nextAttempts >= MAX_PIN_ATTEMPTS) {
      patch.pinLockedUntil = Date.now() + LOCKOUT_MS;
      patch.pinAttempts = 0;
    }
    await update(patch);
    return false;
  }

  async function unlockWithBiometric(): Promise<boolean> {
    if (!settings.biometricCredentialId || !settings.biometricEnabled) return false;
    const ok = await verifyBiometric(settings.biometricCredentialId);
    if (ok) setLocked(false);
    return ok;
  }

  async function setupPin(pin: string): Promise<void> {
    const { hash, salt } = await hashPin(pin);
    await update({ pinHash: hash, pinSalt: salt, pinAttempts: 0, pinLockedUntil: undefined });
    setLocked(false);
  }

  async function changePin(currentPin: string, newPin: string): Promise<boolean> {
    if (!settings.pinHash || !settings.pinSalt) return false;
    const ok = await verifyPin(currentPin, settings.pinHash, settings.pinSalt);
    if (!ok) return false;
    const { hash, salt } = await hashPin(newPin);
    await update({ pinHash: hash, pinSalt: salt });
    return true;
  }

  async function removePin(currentPin: string): Promise<boolean> {
    if (!settings.pinHash || !settings.pinSalt) return false;
    const ok = await verifyPin(currentPin, settings.pinHash, settings.pinSalt);
    if (!ok) return false;
    await update({ pinHash: undefined, pinSalt: undefined, biometricEnabled: false, biometricCredentialId: undefined });
    return true;
  }

  async function enableBiometric(): Promise<boolean> {
    if (!biometricAvailable) return false;
    const credentialId = await registerBiometric('orange-finance-user');
    if (!credentialId) return false;
    await update({ biometricCredentialId: credentialId, biometricEnabled: true });
    return true;
  }

  async function disableBiometric(): Promise<void> {
    await update({ biometricEnabled: false, biometricCredentialId: undefined });
  }

  function lockNow() {
    if (hasPin) setLocked(true);
  }

  function skipForNoPin() {
    setLocked(false);
  }

  const value: AuthLockContextValue = {
    hasPin,
    locked,
    biometricEnabled: settings.biometricEnabled,
    biometricAvailable,
    attemptsLeft,
    lockedUntil,
    unlockWithPin,
    unlockWithBiometric,
    setupPin,
    changePin,
    removePin,
    enableBiometric,
    disableBiometric,
    lockNow,
    skipForNoPin,
  };

  return <AuthLockContext.Provider value={value}>{children}</AuthLockContext.Provider>;
}

export function useAuthLock(): AuthLockContextValue {
  const ctx = useContext(AuthLockContext);
  if (!ctx) throw new Error('useAuthLock deve ser usado dentro de AuthLockProvider');
  return ctx;
}
