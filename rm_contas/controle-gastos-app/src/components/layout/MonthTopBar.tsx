import { useMonth } from '../../contexts';
import { monthTitle } from '../../utils/date';
import { Icon } from '../ui/Icon';

export function MonthTopBar({ rightAction }: { rightAction?: React.ReactNode }) {
  const { month, next, prev, goToday, isCurrent } = useMonth();

  return (
    <header className="topbar">
      <div className="topbar-in">
        <button className="btn icon-only ghost" onClick={prev} aria-label="Mês anterior">
          <Icon name="chevron_left" />
        </button>
        <button
          className="grow row"
          style={{ justifyContent: 'center', gap: 6, fontWeight: 700, fontSize: 15 }}
          onClick={goToday}
          aria-label="Ir para o mês atual"
        >
          {monthTitle(month)}
          {!isCurrent && <span className="pill" style={{ marginLeft: 4 }}>hoje</span>}
        </button>
        <button className="btn icon-only ghost" onClick={next} aria-label="Próximo mês">
          <Icon name="chevron_right" />
        </button>
        {rightAction}
      </div>
    </header>
  );
}
