'use client';

import { useSession } from '@/lib/auth/client';
import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import AppNav from '@/components/layout/AppNav';

type Patient = { id: string; firstName: string; lastName?: string };
type InvitePreview = {
  invite: {
    id: string;
    householdId: string;
    householdName?: string;
    email: string;
    status: string;
    invitedByName?: string;
    expiresAt: string;
  };
  personalPatients: Patient[];
  emailMatches: boolean;
};

export default function AcceptInvitePage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const params = useParams();
  const token = String(params.token || '');

  const [preview, setPreview] = useState<InvitePreview | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`/api/households/invites/${token}`);
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Invite not found');
      setPreview(data);
      setSelected(new Set());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load invite');
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    if (status === 'loading') return;
    if (!session) {
      router.push(`/auth/signin?callbackUrl=${encodeURIComponent(`/households/invites/${token}`)}`);
      return;
    }
    void load();
  }, [session?.user?.id, status, router, load, token]);

  const togglePatient = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const accept = async () => {
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/invites/${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ patientIds: Array.from(selected) }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to accept');
      await fetch('/api/me/active-household', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ householdId: data.householdId }),
      });
      router.push(`/households/${data.householdId}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to accept');
      setBusy(false);
    }
  };

  const decline = async () => {
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/invites/${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ decline: true, patientIds: [] }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to decline');
      router.push('/households');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to decline');
      setBusy(false);
    }
  };

  if (status === 'loading' || !session) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#0175C2] mx-auto" />
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <AppNav />
      <main className="max-w-xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-2xl shadow-xl p-6 space-y-5">
          <h1 className="text-2xl font-bold text-gray-900">Household invitation</h1>

          {loading && <p className="text-gray-500 text-sm">Loading invite...</p>}
          {error && (
            <div className="rounded-md bg-red-50 border border-red-200 text-red-700 px-4 py-3 text-sm">{error}</div>
          )}

          {preview && (
            <>
              <p className="text-gray-700">
                <strong>{preview.invite.invitedByName || 'Someone'}</strong> invited you to join{' '}
                <strong>{preview.invite.householdName || 'a household'}</strong>.
              </p>
              <p className="text-sm text-gray-500">
                Invited email: {preview.invite.email} · Status: {preview.invite.status}
              </p>

              {!preview.emailMatches && (
                <div className="rounded-md bg-amber-50 border border-amber-200 text-amber-900 px-4 py-3 text-sm">
                  You are signed in as a different email than this invite. Sign in with{' '}
                  <strong>{preview.invite.email}</strong> to accept.
                </div>
              )}

              {preview.invite.status === 'pending' && preview.emailMatches && (
                <>
                  <div>
                    <h2 className="font-semibold text-gray-900 mb-2">Bring personal patients into this household?</h2>
                    <p className="text-sm text-gray-600 mb-3">
                      Selected patients move into the shared vault. Leave unchecked to keep them personal.
                    </p>
                    {preview.personalPatients.length === 0 ? (
                      <p className="text-sm text-gray-500">You have no personal patients to move.</p>
                    ) : (
                      <ul className="space-y-2">
                        {preview.personalPatients.map((p) => (
                          <li key={p.id}>
                            <label className="flex items-center gap-2 text-sm text-gray-800">
                              <input
                                type="checkbox"
                                checked={selected.has(p.id)}
                                onChange={() => togglePatient(p.id)}
                              />
                              {[p.firstName, p.lastName].filter(Boolean).join(' ')}
                            </label>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>

                  <div className="flex flex-wrap gap-3">
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void accept()}
                      className="bg-[#0175C2] text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-[#015a96] disabled:opacity-50"
                    >
                      {busy ? 'Joining...' : 'Accept & join'}
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void decline()}
                      className="text-sm font-medium text-gray-600 hover:underline disabled:opacity-50"
                    >
                      Decline
                    </button>
                  </div>
                </>
              )}

              {preview.invite.status !== 'pending' && (
                <Link href="/households" className="text-sm text-[#0175C2] hover:underline">
                  Back to households
                </Link>
              )}
            </>
          )}
        </div>
      </main>
    </div>
  );
}
