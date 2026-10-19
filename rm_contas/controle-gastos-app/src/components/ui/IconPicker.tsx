import { Icon } from './Icon';

export const ICON_CHOICES = [
  'restaurant', 'shopping_cart', 'directions_car', 'home', 'receipt_long', 'medication', 'sports_esports',
  'menu_book', 'shopping_bag', 'subscriptions', 'pets', 'flight_takeoff', 'category', 'payments', 'work',
  'trending_up', 'attach_money', 'local_gas_station', 'fitness_center', 'local_cafe', 'checkroom', 'child_care',
  'celebration', 'spa', 'build', 'wifi', 'phone_iphone', 'movie', 'sports_soccer', 'savings', 'laptop_mac',
  'directions_car_filled', 'cake', 'local_hospital', 'school', 'card_giftcard', 'liquor', 'smoking_rooms',
  'volunteer_activism', 'apartment',
];

export function IconPicker({ value, onChange, color }: { value: string; onChange: (icon: string) => void; color: string }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 8 }}>
      {ICON_CHOICES.map((ic) => (
        <button
          key={ic}
          type="button"
          onClick={() => onChange(ic)}
          style={{
            aspectRatio: '1',
            borderRadius: 12,
            display: 'grid',
            placeItems: 'center',
            border: `1.5px solid ${value === ic ? color : 'var(--line)'}`,
            background: value === ic ? color + '26' : 'var(--surface-2)',
          }}
        >
          <Icon name={ic} style={{ color: value === ic ? color : 'var(--text-2)' }} />
        </button>
      ))}
    </div>
  );
}
