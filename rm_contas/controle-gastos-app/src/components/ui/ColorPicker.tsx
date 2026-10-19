export const COLOR_CHOICES = [
  '#FF8A00', '#FFB347', '#FF5C5C', '#2ECC71', '#4EA1FF', '#A78BFA', '#F0B429', '#C084FC',
  '#38BDF8', '#8BC34A', '#FF6FA5', '#2FD3C6', '#8E95A2', '#F5C518',
];

export function ColorPicker({ value, onChange }: { value: string; onChange: (color: string) => void }) {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
      {COLOR_CHOICES.map((c) => (
        <button
          key={c}
          type="button"
          onClick={() => onChange(c)}
          aria-label={c}
          style={{
            width: 34,
            height: 34,
            borderRadius: '50%',
            background: c,
            border: value === c ? '3px solid var(--text)' : '3px solid transparent',
            boxShadow: value === c ? '0 0 0 2px ' + c : 'none',
          }}
        />
      ))}
    </div>
  );
}
