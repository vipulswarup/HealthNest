'use client';

import { useSession } from '@/lib/auth/client';
import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState } from 'react';
import Image from 'next/image';
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
  shareablePatients: Patient[];
  emailMatches: boolean;
  authenticated?: boolean;
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

  const invitePath = `/households/invites/${token}`;
  const authQuery = useMemo(() => {
    const inviteEmail = preview?.invite.email?.trim().toLowerCase() || '';
    const qs = new URLSearchParams({ callbackUrl: invitePath });
    if (inviteEmail) qs.set('email', inviteEmail);
    return qs.toString();
  }, [invitePath, preview?.invite.email]);

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
    void load();
  }, [status, session?.user?.id, load]);

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

  if (status === 'loading' || loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#0175C2] mx-auto" />
          <p className="mt-4 text-gray-600">Loading invite...</p>
        </div>
      </div>
    );
  }

  const invite = preview?.invite;
  const householdName = invite?.householdName || 'a household';
  const inviterName = invite?.invitedByName || 'Someone';
  const isPending = invite?.status === 'pending';

  // Logged-out: invite pending gate with create / sign-in.
  if (!session) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-6 bg-white rounded-2xl shadow-xl p-8">
          <div className="text-center">
            <div className="flex justify-center mb-4">
              <Image
                src="/logo.png"
                alt="SanoVault Logo"
                width={64}
                height={64}
                className="rounded-full"
                priority
              />
            </div>
            <p className="text-xs font-semibold uppercase tracking-wide text-[#0175C2]">
              Invite pending
            </p>
            <h1 className="mt-2 text-2xl font-bold text-gray-900">
              You&apos;re invited to join {householdName}
            </h1>
            {invite && (
              <p className="mt-2 text-sm text-gray-600">
                <strong>{inviterName}</strong> invited{' '}
                <strong>{invite.email}</strong> to share health records on SanoVault.
              </p>
            )}
          </div>

          {error && (
            <div className="rounded-md bg-red-50 border border-red-200 text-red-700 px-4 py-3 text-sm">
              {error}
            </div>
          )}

          {!invite && !error && (
            <p className="text-sm text-gray-600 text-center">Invite not found.</p>
          )}

          {invite && !isPending && (
            <div className="rounded-md bg-amber-50 border border-amber-200 text-amber-900 px-4 py-3 text-sm">
              This invite is <strong>{invite.status}</strong> and can no longer be accepted.
            </div>
          )}

          {invite && isPending && (
            <div className="space-y-3">
              <Link
                href={`/auth/signup?${authQuery}`}
                className="flex w-full justify-center rounded-lg bg-[#0175C2] px-4 py-3 text-sm font-medium text-white hover:bg-[#015a96] transition-colors"
              >
                Create account
              </Link>
              <Link
                href={`/auth/signin?${authQuery}`}
                className="flex w-full justify-center rounded-lg border border-gray-300 bg-white px-4 py-3 text-sm font-medium text-gray-900 hover:bg-gray-50 transition-colors"
              >
                Already have an account? Sign in
              </Link>
              <p className="text-xs text-center text-gray-500">
                Use <strong>{invite.email}</strong> so we can match this invite to your account.
              </p>
            </div>
          )}
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

          {error && (
            <div className="rounded-md bg-red-50 border border-red-200 text-red-700 px-4 py-3 text-sm">{error}</div>
          )}

          {preview && (
            <>
              <p className="text-gray-800">
                <strong>{inviterName}</strong> invited you to join <strong>{householdName}</strong>.
              </p>
              <p className="text-sm text-gray-600">
                Invited email: {invite?.email} · Status: {invite?.status}
              </p>

              {!preview.emailMatches && (
                <div className="rounded-md bg-amber-50 border border-amber-200 text-amber-900 px-4 py-3 text-sm">
                  You are signed in as a different email than this invite. Sign in with{' '}
                  <strong>{invite?.email}</strong> to accept.
                </div>
              )}

              {isPending && preview.emailMatches && (
                <>
                  <div>
                    <h2 className="font-semibold text-gray-900 mb-2">Also share patients into this household?</h2>
                    <p className="text-sm text-gray-600 mb-3">
                      Optional. Selected patients will also appear in this household (they keep any other household links).
                    </p>
                    {preview.shareablePatients.length === 0 ? (
                      <p className="text-sm text-gray-600">No other patients available to share yet.</p>
                    ) : (
                      <ul className="space-y-2">
                        {preview.shareablePatients.map((p) => (
                          <li key={p.id}>
                            <label className="flex items-center gap-2 text-sm text-gray-900">
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
                      className="text-sm font-medium text-gray-700 hover:underline disabled:opacity-50"
                    >
                      Decline
                    </button>
                  </div>
                </>
              )}

              {!isPending && (
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
