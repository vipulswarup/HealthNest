'use client';

import Link from 'next/link';
import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import AppNav from '@/components/layout/AppNav';
import PersonPicker from '@/components/patients/PersonPicker';
import { useHouseholdContext } from '@/components/households/useHouseholdContext';
import { useSession } from '@/lib/auth/client';
import { getLastPatientId, setLastPatientId } from '@/lib/patients/last-used';

type Patient = { id: string; firstName: string; lastName?: string };

function ForTheDoctorContent() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const searchParams = useSearchParams();
  const { householdId, households, loading: householdsLoading } = useHouseholdContext();
  const [patients, setPatients] = useState<Patient[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [lastPatientId, setLastPatientIdState] = useState<string | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (status === 'loading' || householdsLoading) return;
    if (!session) {
      router.replace('/auth/signin');
      return;
    }
    if (!householdId || households.length === 0) return;

    let active = true;
    void fetch('/api/patients')
      .then(async (response) => {
        const data = await response.json() as Patient[] | { error?: string };
        if (!response.ok) throw new Error((data as { error?: string }).error || 'Could not load family');
        if (active) setPatients(data as Patient[]);
      })
      .catch((err: unknown) => {
        if (active) setError(err instanceof Error ? err.message : 'Could not load family');
      });

    return () => { active = false; };
  }, [householdId, households.length, householdsLoading, router, session, status]);

  const requestedPatientId = searchParams.get('patientId');

  useEffect(() => {
    const stored = getLastPatientId();
    const valid = stored && patients.some((patient) => patient.id === stored) ? stored : null;
    setLastPatientIdState(valid);
    const fromQuery = requestedPatientId && patients.some((patient) => patient.id === requestedPatientId)
      ? requestedPatientId
      : valid;
    if (fromQuery) setSelectedId(fromQuery);
  }, [patients, requestedPatientId]);

  if (status === 'loading' || householdsLoading) {
    return <div className="min-h-screen grid place-items-center bg-slate-50 text-gray-600" role="status">Loading…</div>;
  }
  if (!session) return null;

  const selected = patients.find((patient) => patient.id === selectedId);
  const name = selected ? `${selected.firstName} ${selected.lastName || ''}`.trim() : '';

  return (
    <div className="min-h-screen bg-slate-50">
      <AppNav />
      <main className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
        <h1 className="text-3xl font-bold tracking-tight text-gray-950">For the doctor</h1>
        <p className="mt-2 text-base text-gray-600">Pick who this visit is for, then open medicines or blood work.</p>

        {error && <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>}

        {households.length === 0 ? (
          <p className="mt-8 text-gray-600">Ask a family member to add you to the family folder first.</p>
        ) : patients.length === 0 ? (
          <p className="mt-8 text-gray-600">Add a person first, then you can show a doctor their file.</p>
        ) : (
          <div className="mt-8 space-y-6">
            <PersonPicker
              people={patients}
              selectedId={selectedId || undefined}
              lastUsedId={lastPatientId}
              onSelect={(id) => {
                setLastPatientId(id);
                setSelectedId(id);
              }}
            />
            {selected && (
              <div className="space-y-3">
                <Link
                  href={`/medications/report?patientId=${selected.id}`}
                  className="flex min-h-14 items-center justify-center rounded-xl bg-[#0175C2] px-4 text-base font-medium text-white hover:bg-[#015a96]"
                >
                  Medicines for {name}
                </Link>
                <Link
                  href={`/reports/blood-summary?patientId=${selected.id}`}
                  className="flex min-h-14 items-center justify-center rounded-xl border border-gray-300 bg-white px-4 text-base font-medium text-gray-900 hover:bg-gray-50"
                >
                  Blood work for {name}
                </Link>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
}

export default function ForTheDoctorPage() {
  return (
    <Suspense fallback={<div className="min-h-screen grid place-items-center bg-slate-50 text-gray-600" role="status">Loading…</div>}>
      <ForTheDoctorContent />
    </Suspense>
  );
}

