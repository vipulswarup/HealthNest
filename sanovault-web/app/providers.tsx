'use client';

import { HouseholdProvider } from '@/components/households/useHouseholdContext';
import { ToastProvider } from '@/components/ui/ToastProvider';

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ToastProvider>
      <HouseholdProvider>{children}</HouseholdProvider>
    </ToastProvider>
  );
}
