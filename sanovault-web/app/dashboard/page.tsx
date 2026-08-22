'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import AppNav from '@/components/layout/AppNav';
import { useHouseholdContext } from '@/components/households/useHouseholdContext';
import { useSession } from '@/lib/auth/client';
import { humanizeLabel } from '@/lib/constants/labels';
import { getLastPatientId, setLastPatientId } from '@/lib/patients/last-used';

type PendingInvite = {
  id: string;
  householdName?: string;
  token: string;
  invitedByName?: string;
};

type Patient = { id: string; firstName: string; lastName?: string };
type HealthRecord = {
  id: string;
  patientId: string;
  recordType: string;
  source: string;
  documentDate?: string;
  createdAt: string;
};

function personName(person: Patient) {
  return `${person.firstName} ${person.lastName || ''}`.trim();
}

export default function Dashboard() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const { householdId, households, loading: householdsLoading, refresh } = useHouseholdContext();
  const [pending, setPending] = useState<PendingInvite[]>([]);
  const [patients, setPatients] = useState<Patient[]>([]);
  const [records, setRecords] = useState<HealthRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [lastPatientId, setLastPatientIdState] = useState<string | null>(null);

  useEffect(() => {
    if (status === 'authenticated') void refresh();
  }, [refresh, status]);

  useEffect(() => {
    if (status === 'loading' || householdsLoading) return;
    if (!session) {
      router.replace('/auth/signin');
      return;
    }

    let active = true;
    const loadDashboard = async () => {
      setLoading(true);
      setError('');
      try {
        const inviteResponse = await fetch('/api/households/invites/pending');
        if (active && inviteResponse.ok) {
          const inviteData = await inviteResponse.json();
          setPending(Array.isArray(inviteData) ? inviteData : []);
        }

        if (households.length === 0 || !householdId) {
          if (active) {
            setPatients([]);
            setRecords([]);
          }
          return;
        }

        const [patientsResponse, recordsResponse] = await Promise.all([
          fetch('/api/patients'),
          fetch('/api/health-records'),
        ]);
        if (!patientsResponse.ok || !recordsResponse.ok) throw new Error('Could not load your home screen');
        const patientData = await patientsResponse.json() as Patient[];
        const recordData = await recordsResponse.json() as HealthRecord[];

        if (active) {
          setPatients(patientData);
          setRecords(recordData);
        }
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : 'Could not load your home screen');
      } finally {
        if (active) setLoading(false);
      }
    };

    void loadDashboard();
    return () => { active = false; };
  }, [householdId, households.length, householdsLoading, router, session, status]);

  useEffect(() => {
    const stored = getLastPatientId();
    setLastPatientIdState(stored && patients.some((patient) => patient.id === stored) ? stored : null);
  }, [patients]);

  const people = useMemo(() => {
    if (!lastPatientId) return patients;
    return [...patients].sort((a, b) => Number(b.id === lastPatientId) - Number(a.id === lastPatientId));
  }, [lastPatientId, patients]);

  const recordsByPerson = useMemo(() => {
    const grouped = new Map<string, HealthRecord[]>();
    for (const record of records) {
      const list = grouped.get(record.patientId) || [];
      list.push(record);
      grouped.set(record.patientId, list);
    }
    for (const list of grouped.values()) {
      list.sort((a, b) => new Date(b.documentDate || b.createdAt).getTime() - new Date(a.documentDate || a.createdAt).getTime());
    }
    return grouped;
  }, [records]);

  if (status === 'loading' || householdsLoading) {
    return <div className="min-h-screen grid place-items-center bg-slate-50 text-gray-600" role="status">Loading…</div>;
  }
  if (!session) return null;

  const formatDate = (value: string) => new Intl.DateTimeFormat('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
  }).format(new Date(value));

  const openAdd = (id: string) => {
    setLastPatientId(id);
    router.push(`/health-records/new?patientId=${id}`);
  };

  return (
    <div className="min-h-screen bg-slate-50">
      <AppNav />
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-gray-950">
              Family{session.user.firstName ? `, ${session.user.firstName}` : ''}
            </h1>
            <p className="mt-2 max-w-2xl text-base text-gray-600">Choose a person, add a report, or open what a doctor needs.</p>
          </div>
          <Link href="/patients/new" className="inline-flex min-h-12 items-center justify-center rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-base font-medium text-gray-700 shadow-sm hover:bg-gray-50">
            Add a person
          </Link>
        </div>

        {!householdsLoading && households.length === 0 && (
          <section className="mt-8 rounded-2xl border border-blue-200 bg-blue-50 p-6">
            <h2 className="text-lg font-semibold text-blue-950">No family folder yet</h2>
            <p className="mt-1 text-base text-blue-900">If someone invited you, open the WhatsApp link they sent. Otherwise ask a family member to add you.</p>
            <Link href="/households" className="mt-4 inline-flex min-h-12 items-center rounded-lg bg-[#0175C2] px-4 py-2 text-base font-medium text-white hover:bg-[#015a96]">Who can see this</Link>
          </section>
        )}

        {pending.length > 0 && (
          <section className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-5" aria-labelledby="pending-invites-title">
            <h2 id="pending-invites-title" className="font-semibold text-amber-950">You have an invite</h2>
            <ul className="mt-3 divide-y divide-amber-200">
              {pending.map((invite) => (
                <li key={invite.id} className="flex flex-wrap items-center justify-between gap-3 py-3 text-base text-amber-950">
                  <span>{invite.invitedByName || 'A family member'} invited you to {invite.householdName || 'the family folder'}.</span>
                  <Link href={`/households/invites/${invite.token}`} className="min-h-11 font-medium text-[#0175C2] hover:underline">Open invite</Link>
                </li>
              ))}
            </ul>
          </section>
        )}

        {error && <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-base text-red-800">{error}</div>}

        {households.length > 0 && !loading && patients.length === 0 && (
          <section className="mt-8 rounded-2xl border border-gray-200 bg-white p-8 text-center shadow-sm">
            <h2 className="text-xl font-semibold text-gray-950">Add someone to this folder</h2>
            <p className="mt-2 text-base text-gray-600">Add Dad, your daughter, or anyone whose reports you keep here.</p>
            <Link href="/patients/new" className="mt-6 inline-flex min-h-12 items-center rounded-lg bg-[#0175C2] px-5 py-3 text-base font-medium text-white hover:bg-[#015a96]">
              Add a person
            </Link>
          </section>
        )}

        {households.length > 0 && people.length > 0 && (
          <section className="mt-8 grid gap-4 sm:grid-cols-2" aria-label="Family">
            {people.map((person) => {
              const recent = (recordsByPerson.get(person.id) || []).slice(0, 3);
              const name = personName(person);
              return (
                <article key={person.id} className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
                  <h2 className="text-2xl font-bold text-gray-950">{name}</h2>
                  {person.id === lastPatientId && <p className="mt-1 text-sm font-medium text-[#0175C2]">Last used</p>}
                  <div className="mt-4 grid gap-3">
                    <button
                      type="button"
                      onClick={() => openAdd(person.id)}
                      className="flex min-h-14 items-center justify-center rounded-xl bg-[#0175C2] px-4 text-base font-medium text-white hover:bg-[#015a96]"
                    >
                      Add a report
                    </button>
                    <Link
                      href={`/for-the-doctor?patientId=${person.id}`}
                      onClick={() => setLastPatientId(person.id)}
                      className="flex min-h-14 items-center justify-center rounded-xl border border-gray-300 px-4 text-base font-medium text-gray-800 hover:bg-gray-50"
                    >
                      For the doctor
                    </Link>
                  </div>
                  <div className="mt-5">
                    <p className="text-sm font-medium text-gray-500">Recent files</p>
                    {recent.length === 0 ? (
                      <p className="mt-2 text-base text-gray-600">None yet.</p>
                    ) : (
                      <ul className="mt-2 divide-y divide-gray-100">
                        {recent.map((record) => (
                          <li key={record.id}>
                            <Link href={`/health-records/${record.id}`} className="flex min-h-12 items-center justify-between gap-3 py-2 text-base text-gray-800 hover:text-[#0175C2]">
                              <span className="truncate">{humanizeLabel(record.recordType)}</span>
                              <time className="shrink-0 text-sm text-gray-500">{formatDate(record.documentDate || record.createdAt)}</time>
                            </Link>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                </article>
              );
            })}
          </section>
        )}
      </main>
    </div>
  );
}
