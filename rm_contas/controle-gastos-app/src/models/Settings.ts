export type ThemeMode = 'auto' | 'light' | 'dark';
export type FontScale = 'sm' | 'md' | 'lg' | 'xl';

export interface NotificationPrefs {
  billDue: boolean;
  goalReached: boolean;
  aboveAverage: boolean;
  weeklySummary: boolean;
  monthlySummary: boolean;
}

export interface AppSettings {
  id: 'settings';
  theme: ThemeMode;
  contrast: 'normal' | 'high';
  fontScale: FontScale;
  currency: string;
  language: string;
  /** Primeiro dia do ciclo mensal (1-28). */
  firstDayOfMonth: number;
  defaultGoalId?: string;
  notifications: NotificationPrefs;
  /** Hash PBKDF2 do PIN (nunca o PIN em texto puro). */
  pinHash?: string;
  pinSalt?: string;
  pinAttempts: number;
  pinLockedUntil?: number;
  /** ID da credencial WebAuthn (Face ID / Touch ID / impressão digital) registrada neste aparelho. */
  biometricCredentialId?: string;
  biometricEnabled: boolean;
  rememberUser: boolean;
  onboarded: boolean;
  cloudSyncEnabled: boolean;
  cloudSyncProvider?: string;
}

export const DEFAULT_SETTINGS: AppSettings = {
  id: 'settings',
  theme: 'dark',
  contrast: 'normal',
  fontScale: 'md',
  currency: 'BRL',
  language: 'pt-BR',
  firstDayOfMonth: 1,
  notifications: {
    billDue: true,
    goalReached: true,
    aboveAverage: true,
    weeklySummary: true,
    monthlySummary: true,
  },
  pinAttempts: 0,
  biometricEnabled: false,
  rememberUser: true,
  onboarded: false,
  cloudSyncEnabled: false,
};
