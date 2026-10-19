import { Icon } from './Icon';

export function EmptyState({ icon = 'inbox', title, subtitle }: { icon?: string; title: string; subtitle: string }) {
  return (
    <div className="empty">
      <div className="em-ic">
        <Icon name={icon} />
      </div>
      <h3>{title}</h3>
      <p>{subtitle}</p>
    </div>
  );
}
