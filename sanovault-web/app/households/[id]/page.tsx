'use client';

import { useSession } from '@/lib/auth/client';
import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import AppNav from '@/components/layout/AppNav';

type Member = {
  householdId: string;
  userId: string;
  email?: string;
  firstName?: string;
  lastName?: string;
  joinedAt: string;
};

type Invite = {
  id: string;
  email: string;
  status: string;
  token: string;
  expiresAt: string;
};

type Patient = { id: string; firstName: string; lastName?: string };

function formatOrphanError(data: any): string {
  const names = (data?.details?.patients || [])
    .map((p: any) => [p.firstName, p.lastName].filter(Boolean).join(' '))
    .filter(Boolean);
  if (names.length) {
    return `${data.error} Affected: ${names.join(', ')}.`;
  }
  return data.error || 'Request failed';
}

export default function HouseholdDetailPage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const params = useParams();
  const id = String(params.id || '');

  const [name, setName] = useState('');
  const [editName, setEditName] = useState('');
  const [members, setMembers] = useState<Member[]>([]);
  const [invites, setInvites] = useState<Invite[]>([]);
  const [patients, setPatients] = useState<Patient[]>([]);
  const [linkable, setLinkable] = useState<Patient[]>([]);
  const [linkPatientId, setLinkPatientId] = useState('');
  const [inviteEmail, setInviteEmail] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError('');
    try {
      const [hRes, mRes, iRes, pRes, householdsRes] = await Promise.all([
        fetch(`/api/households/${id}`),
        fetch(`/api/households/${id}/members`),
        fetch(`/api/households/${id}/invites`),
        fetch(`/api/households/${id}/patients`),
        fetch('/api/households'),
      ]);
      if (!hRes.ok) throw new Error('Household not found');
      const household = await hRes.json();
      setName(household.name);
      setEditName(household.name);
      if (mRes.ok) setMembers(await mRes.json());
      if (iRes.ok) setInvites(await iRes.json());
      const householdPatients: Patient[] = pRes.ok ? await pRes.json() : [];
      setPatients(householdPatients);

      // Build linkable list: patients from other households user can access
      if (householdsRes.ok) {
        const households = await householdsRes.json();
        const linkedIds = new Set(householdPatients.map((p) => p.id));
        const others: Patient[] = [];
        for (const h of households) {
          if (h.id === id) continue;
          const op = await fetch(`/api/households/${h.id}/patients`);
          if (!op.ok) continue;
          const list: Patient[] = await op.json();
          for (const p of list) {
            if (!linkedIds.has(p.id) && !others.some((o) => o.id === p.id)) others.push(p);
          }
        }
        setLinkable(others);
        setLinkPatientId(others[0]?.id || '');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    if (status === 'loading') return;
    if (!session) {
      router.push('/auth/signin');
      return;
    }
    void load();
  }, [session?.user?.id, status, router, load]);

  const rename = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: editName }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to rename');
      setName(data.name);
      setMessage('Household renamed');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to rename');
    } finally {
      setBusy(false);
    }
  };

  const sendInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const res = await fetch(`/api/households/${id}/invites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: inviteEmail }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to invite');
      setInviteEmail('');
      setMessage(
        data.emailSent
          ? `Invite sent to ${data.email}`
          : `Invite created for ${data.email}. Email not sent${data.emailError ? `: ${data.emailError}` : ''}. Share: ${data.acceptUrl}`
      );
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to invite');
    } finally {
      setBusy(false);
    }
  };

  const linkPatient = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!linkPatientId) return;
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/${id}/patients`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ patientId: linkPatientId }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to link patient');
      setMessage('Patient linked to household');
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to link');
    } finally {
      setBusy(false);
    }
  };

  const unlinkPatient = async (patientId: string) => {
    if (!confirm('Remove this patient from the household? They must remain in at least one other household.')) return;
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/${id}/patients/${patientId}`, { method: 'DELETE' });
      const data = await res.json();
      if (!res.ok) throw new Error(formatOrphanError(data));
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to unlink');
    } finally {
      setBusy(false);
    }
  };

  const revokeInvite = async (inviteId: string) => {
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/${id}/invites/${inviteId}`, { method: 'DELETE' });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to revoke');
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to revoke');
    } finally {
      setBusy(false);
    }
  };

  const removeMember = async (userId: string) => {
    if (!confirm('Remove this member from the household?')) return;
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/${id}/members/${encodeURIComponent(userId)}`, {
        method: 'DELETE',
      });
      const data = await res.json();
      if (!res.ok) throw new Error(formatOrphanError(data));
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove');
    } finally {
      setBusy(false);
    }
  };

  const leave = async () => {
    if (!confirm('Leave this household? You will lose access unless patients are also in another household you belong to.')) return;
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/${id}/leave`, { method: 'POST' });
      const data = await res.json();
      if (!res.ok) throw new Error(formatOrphanError(data));
      router.push('/households');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to leave');
      setBusy(false);
    }
  };

  const dissolve = async () => {
    if (!confirm('Dissolve this household for everyone? Patients that only exist here must be linked elsewhere first.')) return;
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/households/${id}`, { method: 'DELETE' });
      const data = await res.json();
      if (!res.ok) throw new Error(formatOrphanError(data));
      router.push('/households');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to dissolve');
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

  const currentUserId = session.user?.id;

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <AppNav />
      <main className="max-w-3xl mx-auto py-8 px-4 sm:px-6 lg:px-8 space-y-6">
        <div className="bg-white rounded-2xl shadow-xl p-6 space-y-6">
          {loading ? (
            <p className="text-gray-600">Loading...</p>
          ) : (
            <>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">{name}</h1>
                <p className="text-sm text-gray-600 mt-1">
                  Equal members can invite, manage patients, and share access across households.
                </p>
              </div>

              {error && (
                <div className="rounded-md bg-red-50 border border-red-200 text-red-700 px-4 py-3 text-sm">{error}</div>
              )}
              {message && (
                <div className="rounded-md bg-green-50 border border-green-200 text-green-800 px-4 py-3 text-sm break-all">
                  {message}
                </div>
              )}

              <form onSubmit={rename} className="flex flex-col sm:flex-row gap-3">
                <input
                  type="text"
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                  className="flex-1 border border-gray-300 rounded-md px-3 py-2 text-sm text-gray-900 bg-white"
                  required
                />
                <button type="submit" disabled={busy} className="bg-gray-800 text-white px-4 py-2 rounded-md text-sm font-medium disabled:opacity-50">
                  Rename
                </button>
              </form>

              <section>
                <h2 className="text-lg font-semibold text-gray-900 mb-3">Patients in this household</h2>
                {patients.length === 0 ? (
                  <p className="text-sm text-gray-600 mb-3">No patients yet. <Link href="/patients/new" className="text-[#0175C2] hover:underline">Add a patient</Link>.</p>
                ) : (
                  <ul className="divide-y divide-gray-100 border border-gray-200 rounded-lg overflow-hidden mb-3">
                    {patients.map((p) => (
                      <li key={p.id} className="flex items-center justify-between px-4 py-3 gap-3">
                        <Link href={`/patients/${p.id}`} className="font-medium text-gray-900 hover:text-[#0175C2]">
                          {[p.firstName, p.lastName].filter(Boolean).join(' ')}
                        </Link>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => void unlinkPatient(p.id)}
                          className="text-sm text-red-600 hover:underline disabled:opacity-50"
                        >
                          Unlink
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
                {linkable.length > 0 && (
                  <form onSubmit={linkPatient} className="flex flex-col sm:flex-row gap-3">
                    <select
                      value={linkPatientId}
                      onChange={(e) => setLinkPatientId(e.target.value)}
                      className="flex-1 border border-gray-300 rounded-md px-3 py-2 text-sm text-gray-900 bg-white"
                    >
                      {linkable.map((p) => (
                        <option key={p.id} value={p.id}>
                          {[p.firstName, p.lastName].filter(Boolean).join(' ')}
                        </option>
                      ))}
                    </select>
                    <button type="submit" disabled={busy} className="bg-[#0175C2] text-white px-4 py-2 rounded-md text-sm font-medium disabled:opacity-50">
                      Link existing patient
                    </button>
                  </form>
                )}
              </section>

              <section>
                <h2 className="text-lg font-semibold text-gray-900 mb-3">Members</h2>
                <ul className="divide-y divide-gray-100 border border-gray-200 rounded-lg overflow-hidden">
                  {members.map((m) => (
                    <li key={m.userId} className="flex items-center justify-between px-4 py-3 gap-3">
                      <div>
                        <p className="font-medium text-gray-900">
                          {[m.firstName, m.lastName].filter(Boolean).join(' ') || m.email || m.userId}
                          {m.userId === currentUserId ? ' (you)' : ''}
                        </p>
                        {m.email && <p className="text-sm text-gray-700">{m.email}</p>}
                      </div>
                      {m.userId !== currentUserId && (
                        <button type="button" disabled={busy} onClick={() => void removeMember(m.userId)} className="text-sm text-red-600 hover:underline disabled:opacity-50">
                          Remove
                        </button>
                      )}
                    </li>
                  ))}
                </ul>
              </section>

              <section>
                <h2 className="text-lg font-semibold text-gray-900 mb-3">Invite someone</h2>
                <form onSubmit={sendInvite} className="flex flex-col sm:flex-row gap-3">
                  <input
                    type="email"
                    value={inviteEmail}
                    onChange={(e) => setInviteEmail(e.target.value)}
                    placeholder="email@example.com"
                    className="flex-1 border border-gray-300 rounded-md px-3 py-2 text-sm text-gray-900 bg-white placeholder:text-gray-500"
                    required
                  />
                  <button type="submit" disabled={busy} className="bg-[#0175C2] text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-[#015a96] disabled:opacity-50">
                    Send invite
                  </button>
                </form>
                {invites.filter((i) => i.status === 'pending').length > 0 && (
                  <ul className="mt-4 space-y-2">
                    {invites
                      .filter((i) => i.status === 'pending')
                      .map((invite) => (
                        <li key={invite.id} className="flex items-center justify-between gap-3 border border-gray-200 rounded-lg px-4 py-3 text-sm text-gray-900">
                          <span>
                            {invite.email} · expires {new Date(invite.expiresAt).toLocaleDateString()}
                          </span>
                          <button type="button" disabled={busy} onClick={() => void revokeInvite(invite.id)} className="text-red-600 hover:underline disabled:opacity-50">
                            Revoke
                          </button>
                        </li>
                      ))}
                  </ul>
                )}
              </section>

              <div className="flex flex-wrap gap-3 pt-2 border-t border-gray-100">
                <button type="button" disabled={busy} onClick={() => void leave()} className="text-sm font-medium text-amber-800 hover:underline disabled:opacity-50">
                  Leave household
                </button>
                <button type="button" disabled={busy} onClick={() => void dissolve()} className="text-sm font-medium text-red-700 hover:underline disabled:opacity-50">
                  Dissolve household
                </button>
              </div>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
