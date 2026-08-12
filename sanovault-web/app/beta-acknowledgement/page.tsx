'use client';

import { useSession } from '@/lib/auth/client';
import {
  BETA_ACKNOWLEDGEMENT_TEXT,
  BETA_ACKNOWLEDGEMENT_TITLE,
  BETA_ACKNOWLEDGEMENT_VERSION,
} from '@/lib/legal/beta-acknowledgement';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useMemo, useState } from 'react';

function safeCallbackUrl(value: string | null) {
  return value?.startsWith('/') && !value.startsWith('//') ? value : '/dashboard';
}

function BetaAcknowledgementContent() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const searchParams = useSearchParams();
  const callbackUrl = useMemo(() => safeCallbackUrl(searchParams.get('callbackUrl')), [searchParams]);
  const [agreed, setAgreed] = useState(false);
  const [loading, setLoading] = useState(false);
  const [checking, setChecking] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (status === 'loading') return;
    if (!session) {
      router.replace(`/auth/signin?${new URLSearchParams({ callbackUrl: '/beta-acknowledgement' })}`);
      return;
    }

    let active = true;
    void fetch('/api/users/beta-acknowledgement', { cache: 'no-store' })
      .then(async (response) => ({ response, body: await response.json() as { acknowledged?: boolean } }))
      .then(({ response, body }) => {
        if (!active) return;
        if (!response.ok) {
          setError('We could not verify your acknowledgement. Please try again.');
        } else if (body.acknowledged) {
          router.replace(callbackUrl);
          return;
        }
        setChecking(false);
      })
      .catch(() => {
        if (active) {
          setError('We could not verify your acknowledgement. Please try again.');
          setChecking(false);
        }
      });

    return () => { active = false; };
  }, [callbackUrl, router, session, status]);

  const accept = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!agreed) return;
    setLoading(true);
    setError('');

    try {
      const response = await fetch('/api/users/beta-acknowledgement', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ version: BETA_ACKNOWLEDGEMENT_VERSION }),
      });
      const body = await response.json() as { error?: string };
      if (!response.ok) throw new Error(body.error || 'Unable to save your acknowledgement.');
      router.replace(callbackUrl);
      router.refresh();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Unable to save your acknowledgement.');
    } finally {
      setLoading(false);
    }
  };

  if (status === 'loading' || checking) {
    return <div className="min-h-screen flex items-center justify-center text-gray-600">Loading...</div>;
  }

  return (
    <main className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-indigo-100 px-4 py-12 sm:px-6">
      <section className="mx-auto w-full max-w-2xl rounded-2xl bg-white p-7 shadow-xl sm:p-10">
        <p className="text-sm font-semibold uppercase tracking-wide text-[#0175C2]">Before you continue</p>
        <h1 className="mt-2 text-2xl font-bold text-gray-900 sm:text-3xl">{BETA_ACKNOWLEDGEMENT_TITLE}</h1>
        <div className="mt-6 whitespace-pre-line rounded-xl border border-amber-200 bg-amber-50 p-5 text-sm leading-6 text-gray-800">
          {BETA_ACKNOWLEDGEMENT_TEXT}
        </div>
        <p className="mt-4 text-xs text-gray-500">Acknowledgement version: {BETA_ACKNOWLEDGEMENT_VERSION}</p>

        <form className="mt-6 space-y-5" onSubmit={accept}>
          {error && <p role="alert" className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-800">{error}</p>}
          <label className="flex cursor-pointer gap-3 rounded-xl border border-gray-200 p-4 text-sm text-gray-800">
            <input
              type="checkbox"
              checked={agreed}
              onChange={(event) => setAgreed(event.target.checked)}
              className="mt-0.5 h-4 w-4 rounded border-gray-300 text-[#0175C2] focus:ring-[#0175C2]"
            />
            <span>I have read and agree to this beta and regulatory-status acknowledgement.</span>
          </label>
          <button
            type="submit"
            disabled={!agreed || loading}
            className="w-full rounded-lg bg-[#0175C2] px-4 py-3 text-sm font-medium text-white hover:bg-[#015a96] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? 'Saving acknowledgement...' : 'Agree and continue'}
          </button>
        </form>
      </section>
    </main>
  );
}

export default function BetaAcknowledgementPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-gray-600">Loading...</div>}>
      <BetaAcknowledgementContent />
    </Suspense>
  );
}
