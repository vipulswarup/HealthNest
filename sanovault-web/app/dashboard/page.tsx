'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import AppNav from '@/components/layout/AppNav';
import PersonPicker from '@/components/patients/PersonPicker';
import { useHouseholdContext } from '@/components/households/useHouseholdContext';
import { useSession } from '@/lib/auth/client';
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
type Medication = { id: string; isActive: boolean };

const iconClassName = 'h-5 w-5';

export default function Dashboard() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const { householdId, households, loading: householdsLoading } = useHouseholdContext();
  const [pending, setPending] = useState<PendingInvite[]>([]);
  const [patients, setPatients] = useState<Patient[]>([]);
  const [records, setRecords] = useState<HealthRecord[]>([]);
  const [medications, setMedications] = useState<Medication[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [lastPatientId, setLastPatientIdState] = useState<string | null>(null);

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
            setMedications([]);
          }
          return;
        }

        const [patientsResponse, recordsResponse] = await Promise.all([
          fetch('/api/patients'),
          fetch('/api/health-records'),
        ]);
        if (!patientsResponse.ok || !recordsResponse.ok) throw new Error('Could not load your dashboard');
        const patientData = await patientsResponse.json() as Patient[];
        const recordData = await recordsResponse.json() as HealthRecord[];

        const medicationLists = await Promise.all(patientData.map(async (patient) => {
          const response = await fetch(`/api/medications?patientId=${patient.id}`);
          return response.ok ? await response.json() as Medication[] : [];
        }));

        if (active) {
          setPatients(patientData);
          setRecords(recordData);
          setMedications(medicationLists.flat());
        }
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : 'Could not load your dashboard');
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

  const patientsById = useMemo(
    () => Object.fromEntries(patients.map((patient) => [patient.id, patient])),
    [patients],
  );
  const activeMedicationCount = medications.filter((medication) => medication.isActive).length;

  if (status === 'loading' || householdsLoading) {
    return <div className="min-h-screen grid place-items-center bg-slate-50 text-gray-600" role="status">Loading your vault…</div>;
  }
  if (!session) return null;

  const formatDate = (value: string) => new Intl.DateTimeFormat('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
  }).format(new Date(value));

  return (
    <div className="min-h-screen bg-slate-50">
      <AppNav />
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-medium text-[#0175C2]">Your health vault</p>
            <h1 className="mt-1 text-3xl font-bold tracking-tight text-gray-950">
              Welcome back{session.user.firstName ? `, ${session.user.firstName}` : ''}
            </h1>
            <p className="mt-2 max-w-2xl text-gray-600">Add a report for the right person, or open what changed.</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link href="/patients/new" className="rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50">
              Add family member
            </Link>
            <Link
              href={patients.length > 0 ? '/health-records/new' : '/patients/new'}
              className="rounded-lg bg-[#0175C2] px-4 py-2.5 text-sm font-medium text-white shadow-sm hover:bg-[#015a96]"
            >
              Add a report
            </Link>
          </div>
        </div>

        {!householdsLoading && households.length === 0 && (
          <section className="mt-8 rounded-2xl border border-blue-200 bg-blue-50 p-6">
            <h2 className="text-lg font-semibold text-blue-950">Create your first household</h2>
            <p className="mt-1 text-sm text-blue-900">Patients and records live inside a household so access stays organized.</p>
            <Link href="/households" className="mt-4 inline-flex rounded-lg bg-[#0175C2] px-4 py-2 text-sm font-medium text-white hover:bg-[#015a96]">Create household</Link>
          </section>
        )}

        {pending.length > 0 && (
          <section className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-5" aria-labelledby="pending-invites-title">
            <h2 id="pending-invites-title" className="font-semibold text-amber-950">Pending household invitations</h2>
            <ul className="mt-3 divide-y divide-amber-200">
              {pending.map((invite) => (
                <li key={invite.id} className="flex flex-wrap items-center justify-between gap-3 py-3 text-sm text-amber-950">
                  <span>{invite.invitedByName || 'A member'} invited you to <strong>{invite.householdName || 'a household'}</strong>.</span>
                  <Link href={`/households/invites/${invite.token}`} className="font-medium text-[#0175C2] hover:underline">Review invite</Link>
                </li>
              ))}
            </ul>
          </section>
        )}

        {error && <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>}

        {households.length > 0 && patients.length > 0 && (
          <section className="mt-8 rounded-2xl border border-gray-200 bg-white p-5 shadow-sm" aria-labelledby="add-report-heading">
            <h2 id="add-report-heading" className="font-semibold text-gray-950">Add a report</h2>
            <p className="mt-1 text-sm text-gray-600">Choose who this is for, then take a photo or pick a file from WhatsApp.</p>
            <div className="mt-4">
              <PersonPicker
                people={patients}
                lastUsedId={lastPatientId}
                onSelect={(id) => {
                  setLastPatientId(id);
                  router.push(`/health-records/new?patientId=${id}`);
                }}
              />
            </div>
          </section>
        )}
        {households.length > 0 && (
          <>
            <section className="mt-8 grid gap-4 sm:grid-cols-3" aria-label="Vault overview">
              <Link href="/patients" className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm transition hover:border-blue-200 hover:shadow-md">
                <div className="flex items-center justify-between">
                  <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
                    <svg className={iconClassName} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2m7-10a4 4 0 100-8 4 4 0 000 8zm13 10v-2a4 4 0 00-3-3.87m-2-12a4 4 0 010 7.75" /></svg>
                  </span>
                  <span className="text-3xl font-bold text-gray-950">{loading ? '—' : patients.length}</span>
                </div>
                <h2 className="mt-4 font-semibold text-gray-950">Family</h2>
                <p className="mt-1 text-sm text-gray-600">People in this household</p>
              </Link>
              <Link href="/health-records" className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm transition hover:border-blue-200 hover:shadow-md">
                <div className="flex items-center justify-between">
                  <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50 text-[#0175C2]">
                    <svg className={iconClassName} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5l5 5v11a2 2 0 01-2 2z" /></svg>
                  </span>
                  <span className="text-3xl font-bold text-gray-950">{loading ? '—' : records.length}</span>
                </div>
                <h2 className="mt-4 font-semibold text-gray-950">Reports</h2>
                <p className="mt-1 text-sm text-gray-600">Documents and clinical entries</p>
              </Link>
              <Link href="/medications" className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm transition hover:border-blue-200 hover:shadow-md">
                <div className="flex items-center justify-between">
                  <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-violet-50 text-violet-700">
                    <svg className={iconClassName} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M10.5 6.5l7 7m-9.9 4.9a4.95 4.95 0 01-7-7l7.8-7.8a4.95 4.95 0 017 7l-7.8 7.8z" /></svg>
                  </span>
                  <span className="text-3xl font-bold text-gray-950">{loading ? '—' : activeMedicationCount}</span>
                </div>
                <h2 className="mt-4 font-semibold text-gray-950">Active medications</h2>
                <p className="mt-1 text-sm text-gray-600">Across household patients</p>
              </Link>
            </section>

            <div className="mt-8 grid gap-6 lg:grid-cols-[1.6fr_1fr]">
              <section className="rounded-2xl border border-gray-200 bg-white shadow-sm" aria-labelledby="recent-records-title">
                <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4">
                  <div>
                    <h2 id="recent-records-title" className="font-semibold text-gray-950">Recent records</h2>
                    <p className="mt-0.5 text-sm text-gray-500">Latest additions to the active household</p>
                  </div>
                  <Link href="/health-records" className="text-sm font-medium text-[#0175C2] hover:underline">View all</Link>
                </div>
                {records.length === 0 && !loading ? (
                  <div className="px-5 py-10 text-center text-sm text-gray-600">No records yet. Add the first report to start building the timeline.</div>
                ) : (
                  <ul className="divide-y divide-gray-100">
                    {records.slice(0, 4).map((record) => {
                      const patient = patientsById[record.patientId];
                      return (
                        <li key={record.id}>
                          <Link href={`/health-records/${record.id}`} className="flex items-center justify-between gap-4 px-5 py-4 hover:bg-slate-50">
                            <div className="min-w-0">
                              <p className="truncate font-medium text-gray-950">{record.recordType.replaceAll('_', ' ')}</p>
                              <p className="mt-1 truncate text-sm text-gray-500">{record.source}{patient ? ` · ${patient.firstName} ${patient.lastName || ''}` : ''}</p>
                            </div>
                            <time className="shrink-0 text-sm text-gray-500">{formatDate(record.documentDate || record.createdAt)}</time>
                          </Link>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </section>

              <section className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm" aria-labelledby="quick-actions-title">
                <h2 id="quick-actions-title" className="font-semibold text-gray-950">Quick actions</h2>
                <div className="mt-4 space-y-2">
                  <Link href={lastPatientId ? `/reports/blood-summary?patientId=${lastPatientId}` : '/reports/blood-summary'} className="flex items-center justify-between rounded-xl border border-gray-200 px-4 py-3 text-sm font-medium text-gray-700 hover:border-blue-200 hover:bg-blue-50">Blood work summary <span aria-hidden="true">→</span></Link>
                  <Link href="/medications" className="flex items-center justify-between rounded-xl border border-gray-200 px-4 py-3 text-sm font-medium text-gray-700 hover:border-blue-200 hover:bg-blue-50">Doctor-facing medication list <span aria-hidden="true">→</span></Link>
                  <Link href="/households" className="flex items-center justify-between rounded-xl border border-gray-200 px-4 py-3 text-sm font-medium text-gray-700 hover:border-blue-200 hover:bg-blue-50">Manage household access <span aria-hidden="true">→</span></Link>
                </div>
              </section>
            </div>
          </>
        )}
      </main>
    </div>
  );
}
