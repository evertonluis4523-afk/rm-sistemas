import { type ReactNode, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';

interface BottomSheetProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  headerAction?: ReactNode;
  children: ReactNode;
}

/**
 * Renderizado via portal em document.body para nunca herdar `transform` de
 * ancestrais animados pelas transições de página (o que quebraria `position: fixed`).
 */
export function BottomSheet({ open, onClose, title, headerAction, children }: BottomSheetProps) {
  useEffect(() => {
    if (open) {
      document.body.style.overflow = 'hidden';
      return () => {
        document.body.style.overflow = '';
      };
    }
  }, [open]);

  return createPortal(
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            className="scrim"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            onClick={onClose}
          />
          <div className="sheet-host">
            <motion.div
              className="bsheet"
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 32, stiffness: 320 }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="grab" />
              {title && (
                <div className="sheet-head">
                  <h2>{title}</h2>
                  {headerAction}
                </div>
              )}
              {children}
            </motion.div>
          </div>
        </>
      )}
    </AnimatePresence>,
    document.body
  );
}
