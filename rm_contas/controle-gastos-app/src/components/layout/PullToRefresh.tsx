import { useRef, useState, type ReactNode } from 'react';
import { motion } from 'framer-motion';
import { Icon } from '../ui/Icon';

const THRESHOLD = 70;

export function PullToRefresh({ onRefresh, children }: { onRefresh: () => Promise<void>; children: ReactNode }) {
  const [pull, setPull] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const startY = useRef<number | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  function onTouchStart(e: React.TouchEvent) {
    if ((containerRef.current?.scrollTop ?? 0) <= 0 && !refreshing) {
      startY.current = e.touches[0].clientY;
    }
  }
  function onTouchMove(e: React.TouchEvent) {
    if (startY.current === null) return;
    const delta = e.touches[0].clientY - startY.current;
    if (delta > 0) setPull(Math.min(110, delta * 0.5));
  }
  async function onTouchEnd() {
    if (pull > THRESHOLD && !refreshing) {
      setRefreshing(true);
      await onRefresh();
      setRefreshing(false);
    }
    setPull(0);
    startY.current = null;
  }

  return (
    <div ref={containerRef} onTouchStart={onTouchStart} onTouchMove={onTouchMove} onTouchEnd={onTouchEnd} style={{ minHeight: '100%' }}>
      <motion.div
        style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', overflow: 'hidden' }}
        animate={{ height: refreshing ? 44 : pull }}
      >
        <motion.div animate={{ rotate: refreshing ? 360 : pull * 3 }} transition={refreshing ? { repeat: Infinity, duration: 0.8, ease: 'linear' } : {}}>
          <Icon name="refresh" style={{ color: 'var(--primary)' }} />
        </motion.div>
      </motion.div>
      {children}
    </div>
  );
}
