'use client';

import { useCallback, useEffect, useState } from 'react';

export type HouseholdSummary = {
  id: string;
  name: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
};

export type ActiveHouseholdState = {
  householdId: string | null;
  households: HouseholdSummary[];
  loading: boolean;
  refresh: () => Promise<void>;
  setActive: (householdId: string | null) => Promise<void>;
};

export function useHouseholdContext(): ActiveHouseholdState {
  const [householdId, setHouseholdId] = useState<string | null>(null);
  const [households, setHouseholds] = useState<HouseholdSummary[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const [activeRes, listRes] = await Promise.all([
        fetch('/api/me/active-household'),
        fetch('/api/households'),
      ]);
      if (activeRes.ok) {
        const active = await activeRes.json();
        setHouseholdId(active.householdId ?? null);
      }
      if (listRes.ok) {
        setHouseholds(await listRes.json());
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const setActive = useCallback(async (next: string | null) => {
    const res = await fetch('/api/me/active-household', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ householdId: next }),
    });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || 'Failed to switch household');
    }
    setHouseholdId(next);
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('household-context-changed', { detail: { householdId: next } }));
    }
  }, []);

  return { householdId, households, loading, refresh, setActive };
}
