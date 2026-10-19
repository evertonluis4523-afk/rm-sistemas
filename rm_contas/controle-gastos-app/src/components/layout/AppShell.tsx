import { useEffect, useState } from 'react';
import { Outlet, useLocation, useSearchParams } from 'react-router-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { BottomNav } from './BottomNav';
import { TransactionSheet } from '../transaction/TransactionSheet';
import type { TransactionType } from '../../models';

export function AppShell() {
  const location = useLocation();
  const [params, setParams] = useSearchParams();
  const [quickAdd, setQuickAdd] = useState<{ open: boolean; type: TransactionType }>({ open: false, type: 'expense' });

  // Atalhos do PWA (manifest "shortcuts") chegam como ?new=expense|income
  useEffect(() => {
    const shortcut = params.get('new');
    if (shortcut === 'expense' || shortcut === 'income') {
      setQuickAdd({ open: true, type: shortcut });
      params.delete('new');
      setParams(params, { replace: true });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      <AnimatePresence mode="wait">
        <motion.div
          key={location.pathname}
          initial={{ opacity: 0, x: 8 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -8 }}
          transition={{ duration: 0.16, ease: 'easeOut' }}
        >
          <Outlet />
        </motion.div>
      </AnimatePresence>

      <BottomNav onFabClick={() => setQuickAdd({ open: true, type: 'expense' })} />

      <TransactionSheet open={quickAdd.open} onClose={() => setQuickAdd((q) => ({ ...q, open: false }))} defaultType={quickAdd.type} />
    </>
  );
}
