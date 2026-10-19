import { motion } from 'framer-motion';
import { Icon } from '../components/ui/Icon';

export function Splash() {
  return (
    <div
      style={{
        height: '100dvh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'radial-gradient(1200px 600px at 50% -10%, rgba(255,138,0,0.14), transparent 60%), var(--bg)',
        gap: 22,
      }}
    >
      <motion.div
        initial={{ scale: 0.7, opacity: 0, rotate: -8 }}
        animate={{ scale: 1, opacity: 1, rotate: 0 }}
        transition={{ type: 'spring', damping: 14, stiffness: 160 }}
        style={{
          width: 92,
          height: 92,
          borderRadius: 26,
          background: 'linear-gradient(135deg, var(--primary), var(--primary-2))',
          display: 'grid',
          placeItems: 'center',
          boxShadow: '0 16px 40px rgba(255,138,0,0.4)',
        }}
      >
        <Icon name="account_balance_wallet" size={42} style={{ color: 'var(--on-primary)' }} />
      </motion.div>

      <motion.h1
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2, duration: 0.4 }}
        style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.01em' }}
      >
        Carteira <span style={{ color: 'var(--primary)' }}>Everton</span>
      </motion.h1>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.4 }}
        style={{ width: 140, height: 4, borderRadius: 99, background: 'var(--surface-2)', overflow: 'hidden' }}
      >
        <motion.div
          initial={{ x: '-100%' }}
          animate={{ x: '100%' }}
          transition={{ repeat: Infinity, duration: 1.1, ease: 'easeInOut' }}
          style={{ width: '60%', height: '100%', background: 'linear-gradient(90deg, var(--primary), var(--primary-2))', borderRadius: 99 }}
        />
      </motion.div>
    </div>
  );
}
