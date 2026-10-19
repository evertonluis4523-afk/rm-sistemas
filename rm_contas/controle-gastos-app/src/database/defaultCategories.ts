import type { Category } from '../models';

/** Categorias padrão pré-cadastradas na primeira execução. O usuário pode editar, remover ou criar ilimitadas. */
export const DEFAULT_CATEGORIES: Omit<Category, 'createdAt'>[] = [
  // Despesas
  { id: 'cat-alimentacao', name: 'Alimentação', icon: 'restaurant', color: '#FF5C5C', type: 'expense', isDefault: true },
  { id: 'cat-mercado', name: 'Mercado', icon: 'shopping_cart', color: '#FF8A00', type: 'expense', isDefault: true },
  { id: 'cat-transporte', name: 'Transporte', icon: 'directions_car', color: '#F0B429', type: 'expense', isDefault: true },
  { id: 'cat-moradia', name: 'Moradia', icon: 'home', color: '#4EA1FF', type: 'expense', isDefault: true },
  { id: 'cat-contas', name: 'Contas', icon: 'receipt_long', color: '#8B7CF6', type: 'expense', isDefault: true },
  { id: 'cat-saude', name: 'Saúde', icon: 'medication', color: '#FF6FA5', type: 'expense', isDefault: true },
  { id: 'cat-lazer', name: 'Lazer', icon: 'sports_esports', color: '#A78BFA', type: 'expense', isDefault: true },
  { id: 'cat-educacao', name: 'Educação', icon: 'menu_book', color: '#2FD3C6', type: 'expense', isDefault: true },
  { id: 'cat-compras', name: 'Compras', icon: 'shopping_bag', color: '#F5C518', type: 'expense', isDefault: true },
  { id: 'cat-assinaturas', name: 'Assinaturas', icon: 'subscriptions', color: '#C084FC', type: 'expense', isDefault: true },
  { id: 'cat-pets', name: 'Pets', icon: 'pets', color: '#8BC34A', type: 'expense', isDefault: true },
  { id: 'cat-viagem', name: 'Viagem', icon: 'flight_takeoff', color: '#38BDF8', type: 'expense', isDefault: true },
  { id: 'cat-outros-d', name: 'Outros', icon: 'category', color: '#8E95A2', type: 'expense', isDefault: true },
  // Receitas
  { id: 'cat-salario', name: 'Salário', icon: 'payments', color: '#2ECC71', type: 'income', isDefault: true },
  { id: 'cat-freela', name: 'Renda extra', icon: 'work', color: '#34D399', type: 'income', isDefault: true },
  { id: 'cat-investimentos', name: 'Investimentos', icon: 'trending_up', color: '#10B981', type: 'income', isDefault: true },
  { id: 'cat-outros-r', name: 'Outros', icon: 'attach_money', color: '#22C55E', type: 'income', isDefault: true },
];
