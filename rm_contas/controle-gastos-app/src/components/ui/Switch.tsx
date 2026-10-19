export function Switch({ on, onClick, ariaLabel }: { on: boolean; onClick: () => void; ariaLabel?: string }) {
  return (
    <button type="button" role="switch" aria-checked={on} aria-label={ariaLabel} className={`switch${on ? ' on' : ''}`} onClick={onClick} />
  );
}
