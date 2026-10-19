import { useNavigate } from 'react-router-dom';
import { Icon } from '../ui/Icon';

interface PageTopBarProps {
  title: string;
  back?: boolean;
  rightAction?: React.ReactNode;
}

export function PageTopBar({ title, back, rightAction }: PageTopBarProps) {
  const navigate = useNavigate();
  return (
    <header className="topbar">
      <div className="topbar-in">
        {back && (
          <button className="btn icon-only ghost" onClick={() => navigate(-1)} aria-label="Voltar">
            <Icon name="arrow_back" />
          </button>
        )}
        <h1 className="grow" style={{ fontSize: 17, fontWeight: 800, fontFamily: 'var(--font-display)' }}>
          {title}
        </h1>
        {rightAction}
      </div>
    </header>
  );
}
