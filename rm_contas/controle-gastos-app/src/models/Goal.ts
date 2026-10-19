export type GoalKind = 'travel' | 'house' | 'car' | 'notebook' | 'reserve' | 'custom';

export interface Goal {
  id: string;
  name: string;
  kind: GoalKind;
  icon: string;
  color: string;
  /** Em centavos. */
  targetAmount: number;
  /** Em centavos. */
  currentAmount: number;
  targetDate?: string;
  createdAt: number;
  updatedAt: number;
}

export const GOAL_PRESETS: { kind: GoalKind; name: string; icon: string; color: string }[] = [
  { kind: 'travel', name: 'Viagem', icon: 'flight_takeoff', color: '#4EA1FF' },
  { kind: 'house', name: 'Casa', icon: 'home', color: '#2ECC71' },
  { kind: 'car', name: 'Carro', icon: 'directions_car', color: '#FF8A00' },
  { kind: 'notebook', name: 'Notebook', icon: 'laptop_mac', color: '#A78BFA' },
  { kind: 'reserve', name: 'Reserva de emergência', icon: 'savings', color: '#F0B429' },
  { kind: 'custom', name: 'Meta personalizada', icon: 'flag', color: '#FF5C5C' },
];
