import { createContext, useContext, useEffect, useMemo, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../database/db';
import { DEFAULT_SETTINGS, type AppSettings } from '../models';

interface SettingsContextValue {
  settings: AppSettings;
  loading: boolean;
  update: (patch: Partial<AppSettings>) => Promise<void>;
}

const SettingsContext = createContext<SettingsContextValue | null>(null);

export function SettingsProvider({ children }: { children: ReactNode }) {
  const raw = useLiveQuery(() => db.settings.get('settings'), []);
  const settings = raw ?? DEFAULT_SETTINGS;
  const loading = raw === undefined;

  useEffect(() => {
    const root = document.documentElement;
    if (settings.theme === 'auto') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', settings.theme);
    root.setAttribute('data-contrast', settings.contrast);
    root.setAttribute('data-font-scale', settings.fontScale);
  }, [settings.theme, settings.contrast, settings.fontScale]);

  const value = useMemo<SettingsContextValue>(
    () => ({
      settings,
      loading,
      update: async (patch) => {
        await db.settings.update('settings', patch);
      },
    }),
    [settings, loading]
  );

  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>;
}

export function useSettings(): SettingsContextValue {
  const ctx = useContext(SettingsContext);
  if (!ctx) throw new Error('useSettings deve ser usado dentro de SettingsProvider');
  return ctx;
}
