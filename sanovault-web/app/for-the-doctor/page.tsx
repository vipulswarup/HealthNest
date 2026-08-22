'use client';

import Link from 'next/link';
import { Suspense, useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import AppNav from '@/components/layout/AppNav';
import PersonPicker from '@/components/patients/PersonPicker';
import { useHouseholdContext } from '@/components/households/useHouseholdContext';
import { useSession } from '@/lib/auth/client';
import { getLastPatientId, setLastPatientId } from '@/lib/patients/last-used';
import { doctorPacketWhatsAppText } from '@/lib/reports/doctor-packet';
import { whatsappShareHref } from '@/lib/share/whatsapp';
import dynamic from 'next/dynamic';

const ShareCopy = dynamic(
  () => import('@/components/documents/ShareCopy').then((mod) => mod.ShareCopy),
  { ssr: false },
);

type Patient = { id: string; firstName: string; lastName?: string };

type Packet = {
  patient: {
    id: string;
    firstName: string;
    lastName: string;
    dateOfBirth: string | null;
    age: number | null;
    gender: string;
    bloodGroup: string;
  };
  conditions: string[];
  medicines: Array<{ id: string; line: string }>;
  labHighlights: string[];
  bloodPressure: { available: boolean; lines: string[] };
  pleaseAsk: string;
  documents: Array<{ id: string; documentId: string | null; label: string; href: string }>;
};

function personName(person: { firstName: string; lastName?: string }) {
  return `${person.firstName} ${person.lastName || ''}`.trim();
}

function ForTheDoctorContent() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const searchParams = useSearchParams();
  const { householdId, households, loading: householdsLoading } = useHouseholdContext();
  const [patients, setPatients] = useState<Patient[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [lastPatientId, setLastPatientIdState] = useState<string | null>(null);
  const [packet, setPacket] = useState<Packet | null>(null);
  const [packetLoading, setPacketLoading] = useState(false);
  const [pleaseAsk, setPleaseAsk] = useState('');
  const [savingAsk, setSavingAsk] = useState(false);
  const [error, setError] = useState('');
  const [origin, setOrigin] = useState('https://sanovault.com');

  useEffect(() => {
    setOrigin(window.location.origin);
  }, []);

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

  const loadPacket = useCallback(async (patientId: string) => {
    setError('');
    setPacket(null);
    setPacketLoading(true);
    try {
      const response = await fetch(`/api/reports/doctor-packet?patientId=${patientId}`);
      const data = await response.json() as Packet | { error?: string };
      if (!response.ok) throw new Error((data as { error?: string }).error || 'Could not prepare the packet');
      const loaded = data as Packet;
      setPacket(loaded);
      setPleaseAsk(loaded.pleaseAsk || '');
    } finally {
      setPacketLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!selectedId) {
      setPacket(null);
      return;
    }
    let active = true;
    void loadPacket(selectedId).catch((err: unknown) => {
      if (active) setError(err instanceof Error ? err.message : 'Could not prepare the packet');
    });
    return () => { active = false; };
  }, [loadPacket, selectedId]);

  const selectPerson = (id: string) => {
    setLastPatientId(id);
    setSelectedId(id);
    router.replace(`/for-the-doctor?patientId=${id}`, { scroll: false });
  };

  const savePleaseAsk = async () => {
    if (!selectedId || !packet) return;
    setSavingAsk(true);
    setError('');
    try {
      const current = await fetch(`/api/patients/${selectedId}`);
      const currentBody = await current.json() as { preferences?: Record<string, unknown>; error?: string };
      if (!current.ok) throw new Error(currentBody.error || 'Could not save notes');
      const response = await fetch(`/api/patients/${selectedId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          preferences: { ...(currentBody.preferences || {}), pleaseAsk },
        }),
      });
      const body = await response.json() as { error?: string };
      if (!response.ok) throw new Error(body.error || 'Could not save notes');
      setPacket({ ...packet, pleaseAsk });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save notes');
    } finally {
      setSavingAsk(false);
    }
  };

  const selected = patients.find((patient) => patient.id === selectedId);
  const name = packet ? personName(packet.patient) : selected ? personName(selected) : '';
  const identityBits = packet
    ? [
        packet.patient.age !== null ? `${packet.patient.age} years` : '',
        packet.patient.gender,
        packet.patient.bloodGroup ? `Blood group ${packet.patient.bloodGroup}` : '',
      ].filter(Boolean)
    : [];
  const identityLine = identityBits.join(' · ');

  const whatsappHref = useMemo(() => {
    if (!packet || !selectedId) return '';
    return whatsappShareHref(doctorPacketWhatsAppText({
      origin,
      patientId: selectedId,
      name,
      identityLine,
      conditions: packet.conditions,
      medicines: packet.medicines.map((medication) => medication.line),
      labHighlights: packet.labHighlights,
      bloodPressure: packet.bloodPressure.lines,
      pleaseAsk,
      documents: packet.documents.map((document) => ({
        label: document.label,
        href: `${origin.replace(/\/$/, '')}${document.href}`,
      })),
    }));
  }, [identityLine, name, origin, packet, pleaseAsk, selectedId]);

  if (status === 'loading' || householdsLoading) {
    return <div className="min-h-screen grid place-items-center bg-slate-50 text-gray-600" role="status">Loading…</div>;
  }
  if (!session) return null;

  return (
    <div className="min-h-screen bg-slate-50">
      <AppNav />
      <main className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
        <div className="print:hidden">
          <h1 className="text-3xl font-bold tracking-tight text-gray-950">For the doctor</h1>
          <p className="mt-2 text-base text-gray-600">One page for a clinic visit. Print it, or send it on WhatsApp.</p>
        </div>

        {error && <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 print:hidden">{error}</div>}

        {households.length === 0 ? (
          <p className="mt-8 text-gray-600 print:hidden">Ask a family member to add you to the family folder first.</p>
        ) : patients.length === 0 ? (
          <p className="mt-8 text-gray-600 print:hidden">Add a person first, then you can show a doctor their file.</p>
        ) : (
          <div className="mt-8 space-y-6">
            <div className="print:hidden">
              <PersonPicker
                people={patients}
                selectedId={selectedId || undefined}
                lastUsedId={lastPatientId}
                onSelect={selectPerson}
              />
            </div>

            {selected && packetLoading && (
              <p className="text-gray-600 print:hidden" role="status">Preparing the packet…</p>
            )}

            {selected && packet && (
              <>
                <div className="flex flex-wrap gap-3 print:hidden">
                  <button
                    type="button"
                    onClick={() => window.print()}
                    className="inline-flex min-h-12 items-center justify-center rounded-xl bg-[#0175C2] px-4 text-base font-medium text-white hover:bg-[#015a96]"
                  >
                    Print
                  </button>
                  <a
                    href={whatsappHref}
                    className="inline-flex min-h-12 items-center justify-center rounded-xl border border-gray-300 bg-white px-4 text-base font-medium text-gray-900 hover:bg-gray-50"
                  >
                    Send on WhatsApp
                  </a>
                  <ShareCopy
                    documents={packet.documents
                      .filter((document) => document.documentId)
                      .map((document) => ({ id: document.documentId as string, label: document.label }))}
                    cover={{
                      title: name,
                      identityLine,
                      sections: [
                        { heading: 'Conditions', lines: packet.conditions },
                        { heading: 'Current medicines', lines: packet.medicines.map((medication) => medication.line) },
                          { heading: 'Lab highlights', lines: packet.labHighlights },
                          { heading: 'Blood pressure', lines: packet.bloodPressure.lines },
                          { heading: 'Please ask', lines: pleaseAsk.trim() ? pleaseAsk.trim().split('\n').filter(Boolean) : [] },
                      ],
                    }}
                    defaultWatermark={`Confidential — For the treating doctor — ${name}`}
                    defaultFileName={`${name.replace(/\s+/g, '-')}-doctor-packet.pdf`}
                  />
                </div>

                <article className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm print:border-0 print:p-0 print:shadow-none">
                  <p className="text-sm font-medium uppercase tracking-wide text-[#0175C2]">For the doctor</p>
                  <h2 className="mt-1 text-4xl font-bold tracking-tight text-gray-950">{name}</h2>
                  {identityLine && <p className="mt-2 text-lg text-gray-700">{identityLine}</p>}

                  <section className="mt-8">
                    <h3 className="text-lg font-semibold text-gray-950">Conditions</h3>
                    {packet.conditions.length === 0 ? (
                      <p className="mt-2 text-gray-600">None recorded.</p>
                    ) : (
                      <ul className="mt-2 list-disc space-y-1 pl-5 text-gray-800">
                        {packet.conditions.map((line) => <li key={line}>{line}</li>)}
                      </ul>
                    )}
                  </section>

                  <section className="mt-6">
                    <h3 className="text-lg font-semibold text-gray-950">Current medicines</h3>
                    {packet.medicines.length === 0 ? (
                      <p className="mt-2 text-gray-600">None recorded.</p>
                    ) : (
                      <ul className="mt-2 list-disc space-y-1 pl-5 text-gray-800">
                        {packet.medicines.map((medication) => <li key={medication.id}>{medication.line}</li>)}
                      </ul>
                    )}
                  </section>

                  <section className="mt-6">
                    <h3 className="text-lg font-semibold text-gray-950">Lab highlights</h3>
                    {packet.labHighlights.length === 0 ? (
                      <p className="mt-2 text-gray-600">No recent lab highlights.</p>
                    ) : (
                      <ul className="mt-2 list-disc space-y-1 pl-5 text-gray-800">
                        {packet.labHighlights.map((line) => <li key={line}>{line}</li>)}
                      </ul>
                    )}
                  </section>

                  <section className="mt-6">
                    <h3 className="text-lg font-semibold text-gray-950">Blood pressure</h3>
                    {packet.bloodPressure.lines.length === 0 ? (
                      <p className="mt-2 text-gray-600">Not logged in SanoVault yet.</p>
                    ) : (
                      <ul className="mt-2 list-disc space-y-1 pl-5 text-gray-800">
                        {packet.bloodPressure.lines.map((line) => <li key={line}>{line}</li>)}
                      </ul>
                    )}
                  </section>

                  <section className="mt-6">
                    <h3 className="text-lg font-semibold text-gray-950">Please ask</h3>
                    <textarea
                      value={pleaseAsk}
                      onChange={(event) => setPleaseAsk(event.target.value)}
                      rows={3}
                      placeholder="Questions for this visit"
                      className="mt-2 w-full rounded-lg border border-gray-300 px-3 py-2 text-base text-gray-900 print:hidden"
                    />
                    <button
                      type="button"
                      onClick={() => void savePleaseAsk()}
                      disabled={savingAsk}
                      className="mt-2 min-h-11 rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-800 hover:bg-gray-50 disabled:opacity-50 print:hidden"
                    >
                      {savingAsk ? 'Saving…' : 'Save notes'}
                    </button>
                    <div className="hidden print:block">
                      {pleaseAsk.trim()
                        ? pleaseAsk.trim().split('\n').filter(Boolean).map((line) => <p key={line} className="mt-1 text-gray-800">{line}</p>)
                        : <p className="mt-2 text-gray-600">None.</p>}
                    </div>
                  </section>

                  <section className="mt-6">
                    <h3 className="text-lg font-semibold text-gray-950">Reports</h3>
                    {packet.documents.length === 0 ? (
                      <p className="mt-2 text-gray-600">No attached files yet.</p>
                    ) : (
                      <ul className="mt-2 space-y-1">
                        {packet.documents.map((document) => (
                          <li key={document.id}>
                            <Link href={document.href} className="text-[#0175C2] hover:underline">
                              {document.label}
                            </Link>
                          </li>
                        ))}
                      </ul>
                    )}
                  </section>
                </article>
              </>
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
