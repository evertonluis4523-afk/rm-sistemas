import { type HTMLAttributes, type ReactNode } from 'react';
import { motion } from 'framer-motion';

type DivPropsSafe = Omit<HTMLAttributes<HTMLDivElement>, 'onDrag' | 'onDragStart' | 'onDragEnd' | 'onAnimationStart' | 'onAnimationEnd'>;

interface CardProps extends DivPropsSafe {
  pad?: boolean;
  elevated?: boolean;
  interactive?: boolean;
  children: ReactNode;
}

export function Card({ pad = true, elevated, interactive, className = '', children, ...rest }: CardProps) {
  const classes = ['card', pad ? 'pad' : '', elevated ? 'elevated' : '', interactive ? 'interactive' : '', className].filter(Boolean).join(' ');
  if (interactive) {
    return (
      <motion.div className={classes} whileTap={{ scale: 0.98 }} {...(rest as Record<string, unknown>)}>
        {children}
      </motion.div>
    );
  }
  return (
    <div className={classes} {...rest}>
      {children}
    </div>
  );
}
