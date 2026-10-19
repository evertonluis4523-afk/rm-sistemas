import { useEffect, useState } from 'react';
import { HashRouter, Routes, Route } from 'react-router-dom';
import { SettingsProvider, ToastProvider, AuthLockProvider, MonthProvider, useAuthLock, useSettings } from './contexts';
import { ensureSeeded } from './database/seed';
import { materializeRecurring } from './services/recurringEngine';
import { Splash } from './pages/Splash';
import { Login } from './pages/Login';
import { AppShell } from './components/layout/AppShell';
import { Dashboard } from './pages/Dashboard';
import { Transactions } from './pages/Transactions';
import { Accounts } from './pages/Accounts';
import { Cards } from './pages/Cards';
import { Categories } from './pages/Categories';
import { Budgets } from './pages/Budgets';
import { Calendar } from './pages/Calendar';
import { Search } from './pages/Search';
import { Goals } from './pages/Goals';
import { Reports } from './pages/Reports';
import { History } from './pages/History';
import { Backup } from './pages/Backup';
import { Settings } from './pages/Settings';
import { More } from './pages/More';

const MIN_SPLASH_MS = 900;

function Gate({ children }: { children: React.ReactNode }) {
  const { settings, loading } = useSettings();
  const { locked, hasPin } = useAuthLock();
  const [minTimeElapsed, setMinTimeElapsed] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setMinTimeElapsed(true), MIN_SPLASH_MS);
    return () => clearTimeout(t);
  }, []);

  if (loading || !minTimeElapsed) return <Splash />;
  if (!settings.onboarded || (hasPin && locked)) return <Login />;
  return <>{children}</>;
}

function AppRoutes() {
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route path="/" element={<Dashboard />} />
        <Route path="/lancamentos" element={<Transactions />} />
        <Route path="/contas" element={<Accounts />} />
        <Route path="/cartoes" element={<Cards />} />
        <Route path="/categorias" element={<Categories />} />
        <Route path="/orcamentos" element={<Budgets />} />
        <Route path="/calendario" element={<Calendar />} />
        <Route path="/busca" element={<Search />} />
        <Route path="/metas" element={<Goals />} />
        <Route path="/relatorios" element={<Reports />} />
        <Route path="/historico" element={<History />} />
        <Route path="/backup" element={<Backup />} />
        <Route path="/configuracoes" element={<Settings />} />
        <Route path="/mais" element={<More />} />
      </Route>
    </Routes>
  );
}

function AppBootstrap() {
  useEffect(() => {
    ensureSeeded().then(() => materializeRecurring());
  }, []);

  return (
    <Gate>
      <MonthProvider>
        <HashRouter>
          <AppRoutes />
        </HashRouter>
      </MonthProvider>
    </Gate>
  );
}

export default function App() {
  return (
    <SettingsProvider>
      <ToastProvider>
        <AuthLockProvider>
          <AppBootstrap />
        </AuthLockProvider>
      </ToastProvider>
    </SettingsProvider>
  );
}
