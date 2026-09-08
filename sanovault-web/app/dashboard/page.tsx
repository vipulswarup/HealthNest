'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card } from '@heroui/react';
import AppNav from '@/components/layout/AppNav';
import { PersonCardActions } from '@/components/dashboard/PersonCardActions';
import { useHouseholdContext } from '@/components/households/useHouseholdContext';
import { useSession } from '@/lib/auth/client';
import { humanizeLabel } from '@/lib/constants/labels';
import { getLastPatientId, setLastPatientId } from '@/lib/patients/last-used';
import { svBtnOutline, svBtnPrimary } from '@/lib/ui/buttons';

type PendingInvite = {
  id: string;
  householdName?: string;
  token: string;
  invitedByName?: string;
};

type Patient = { id: string; firstName: string; lastName?: string; dateOfBirth?: string | Date | null };
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
    <div className="min-h-screen bg-background">
      <AppNav />
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-ink">
              Family{session.user.firstName ? `, ${session.user.firstName}` : ''}
            </h1>
            <p className="mt-2 max-w-2xl text-base text-blue-slate">Choose a Person, Add a Report, or Open What a Doctor Needs.</p>
          </div>
          <Link href="/patients/new" className={svBtnOutline}>
            Add a Person
          </Link>
        </div>

        {!householdsLoading && households.length === 0 && (
          <section className="mt-8 rounded-2xl border border-silver bg-white p-6">
            <h2 className="text-lg font-semibold text-ink">No Family Folder Yet</h2>
            <p className="mt-1 text-base text-blue-slate">If someone invited you, open the WhatsApp link they sent. Otherwise ask a family member to add you.</p>
            <Link href="/households" className={`${svBtnPrimary} mt-4`}>Who Can See This</Link>
          </section>
        )}

        {pending.length > 0 && (
          <section className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-5" aria-labelledby="pending-invites-title">
            <h2 id="pending-invites-title" className="font-semibold text-amber-950">You Have an Invite</h2>
            <ul className="mt-3 divide-y divide-amber-200">
              {pending.map((invite) => (
                <li key={invite.id} className="flex flex-wrap items-center justify-between gap-3 py-3 text-base text-amber-950">
                  <span>{invite.invitedByName || 'A Family Member'} invited you to {invite.householdName || 'the family folder'}.</span>
                  <Link href={`/households/invites/${invite.token}`} className="min-h-11 font-medium text-coral hover:underline">Open Invite</Link>
                </li>
              ))}
            </ul>
          </section>
        )}

        {error && <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-base text-red-800">{error}</div>}

        {households.length > 0 && !loading && patients.length === 0 && (
          <section className="mt-8 rounded-2xl border border-silver bg-white p-8 text-center shadow-sm">
            <h2 className="text-xl font-semibold text-ink">Add Someone to This Folder</h2>
            <p className="mt-2 text-base text-blue-slate">Add Dad, your daughter, or anyone whose reports you keep here.</p>
            <Link href="/patients/new" className={`${svBtnPrimary} mt-6`}>
              Add a Person
            </Link>
          </section>
        )}

        {households.length > 0 && people.length > 0 && (
          <section className="mt-8 grid gap-4 sm:grid-cols-2" aria-label="Family">
            {people.map((person) => {
              const recent = (recordsByPerson.get(person.id) || []).slice(0, 3);
              const name = personName(person);
              return (
                <Card key={person.id} className="h-full p-5">
                  <h2 className="text-2xl font-bold text-ink">{name}</h2>
                  <p className={`mt-1 min-h-6 text-sm font-medium ${person.id === lastPatientId ? 'text-coral' : 'invisible'}`}>
                    Last Used
                  </p>
                  <PersonCardActions
                    patientId={person.id}
                    onAddReport={() => openAdd(person.id)}
                    onNavigate={() => setLastPatientId(person.id)}
                  />
                  <div className="mt-5">
                    <div className="flex items-center justify-between gap-3">
                      <p className="text-sm font-medium text-blue-slate">Recent Files</p>
                      <Link
                        href={`/health-records?patientId=${person.id}`}
                        onClick={() => setLastPatientId(person.id)}
                        className="text-sm font-medium text-coral hover:underline"
                      >
                        View All
                      </Link>
                    </div>
                    {recent.length === 0 ? (
                      <p className="mt-2 text-base text-gray-600">None yet.</p>
                    ) : (
                      <ul className="mt-2 divide-y divide-gray-100">
                        {recent.map((record) => (
                          <li key={record.id}>
                            <Link href={`/health-records/${record.id}`} className="flex min-h-12 items-center justify-between gap-3 py-2 text-base text-ink hover:text-coral">
                              <span className="truncate">{humanizeLabel(record.recordType)}</span>
                              <time className="shrink-0 text-sm text-gray-500">{formatDate(record.documentDate || record.createdAt)}</time>
                            </Link>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                </Card>
              );
            })}
          </section>
        )}
      </main>
    </div>
  );
}
