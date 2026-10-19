interface SegOption {
  id: string;
  label: string;
}

export function Seg({ options, value, onChange }: { options: SegOption[]; value: string; onChange: (id: string) => void }) {
  return (
    <div className="seg">
      {options.map((o) => (
        <button key={o.id} className={value === o.id ? 'on' : ''} onClick={() => onChange(o.id)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}
