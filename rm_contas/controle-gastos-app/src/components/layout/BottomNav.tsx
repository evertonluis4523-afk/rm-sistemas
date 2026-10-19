import { NavLink } from 'react-router-dom';
import { Icon } from '../ui/Icon';

const TABS = [
  { to: '/', label: 'Início', icon: 'home' },
  { to: '/lancamentos', label: 'Extrato', icon: 'receipt_long' },
  { to: '__fab__', label: '', icon: '' },
  { to: '/contas', label: 'Carteira', icon: 'account_balance_wallet' },
  { to: '/mais', label: 'Mais', icon: 'apps' },
] as const;

export function BottomNav({ onFabClick }: { onFabClick: () => void }) {
  return (
    <nav className="tabbar">
      {TABS.map((tab) =>
        tab.to === '__fab__' ? (
          <div key="fab-slot" className="tab-fab-slot">
            <button className="tab-fab" onClick={onFabClick} aria-label="Novo lançamento">
              <Icon name="add" />
            </button>
          </div>
        ) : (
          <NavLink key={tab.to} to={tab.to} end={tab.to === '/'} className={({ isActive }) => `tab${isActive ? ' on' : ''}`}>
            <span className="tab-pill">
              <Icon name={tab.icon} />
            </span>
            <span className="tab-label">{tab.label}</span>
          </NavLink>
        )
      )}
    </nav>
  );
}
