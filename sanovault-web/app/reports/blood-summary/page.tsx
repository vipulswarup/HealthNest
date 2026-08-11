'use client';

import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useSession } from '@/lib/auth/client';

interface SummaryResponse {
  patient: { id: string; firstName: string; lastName: string };
  periodStart: string;
  periodEnd: string;
  candidateReportCount: number;
  reports: Array<{ id: string; date: string; source: string; documentPath?: string; results: Array<{ metric: string }> }>;
  comparisons: Array<{ metric: string; label: string; unit: string | null; direction: string; change: number | null; results: Array<{ value: number; unit: string | null; status: string; date: string; reportId: string; documentPath?: string }> }>;
  keyFindings: Array<{ severity: string; text: string }>;
}

const date = (value: string) => new Intl.DateTimeFormat('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(value));
const value = (result: { value: number; unit: string | null }) => `${result.value}${result.unit ? ` ${result.unit}` : ''}`;

function BloodSummaryContent() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const searchParams = useSearchParams();
  const patientId = searchParams.get('patientId');
  const [patients, setPatients] = useState<Array<{ id: string; firstName: string; lastName?: string }>>([]);
  const [summary, setSummary] = useState<SummaryResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (status !== 'loading' && !session) router.replace('/auth/signin');
  }, [session?.user?.id, status, router]);

  useEffect(() => {
    if (!session) return;
    fetch('/api/patients').then((response) => response.ok ? response.json() : Promise.reject(new Error('Could not load patients')))
      .then(setPatients).catch((err) => setError(err.message));
  }, [session]);

  useEffect(() => {
    if (!patientId || !session) return;
    const selectedPatientId = patientId;
    let cancelled = false;
    async function loadSummary() {
      setLoading(true);
      setError('');
      try {
        const response = await fetch(`/api/reports/blood-summary?patientId=${encodeURIComponent(selectedPatientId)}`);
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.error || 'Could not generate the report');
        if (!cancelled) setSummary(payload);
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Could not generate the report');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void loadSummary();
    return () => { cancelled = true; };
  }, [patientId, session]);

  const selectPatient = (id: string) => router.push(`/reports/blood-summary?patientId=${id}`);

  if (status === 'loading' || !session) return <div className="min-h-screen grid place-items-center text-gray-600">Loading…</div>;

  return (
    <main className="min-h-screen bg-slate-50 px-4 py-8 sm:px-8">
      <div className="mx-auto max-w-6xl">
        <div className="mb-6 flex flex-wrap items-center justify-between gap-4 print:hidden">
          <div><h1 className="text-3xl font-bold text-slate-900">Blood report summary</h1><p className="mt-1 text-slate-600">A clinician-friendly comparison of the past 90 days.</p></div>
          <button onClick={() => window.print()} disabled={!summary} className="rounded-lg bg-[#0175C2] px-4 py-2 font-medium text-white disabled:cursor-not-allowed disabled:bg-slate-300">Print / Save PDF</button>
        </div>

        <section className="mb-6 rounded-xl bg-white p-5 shadow-sm print:shadow-none">
          <label htmlFor="patient" className="mb-2 block text-sm font-medium text-slate-700">Patient</label>
          <select id="patient" value={patientId || ''} onChange={(event) => selectPatient(event.target.value)} className="w-full max-w-md rounded-lg border border-slate-300 px-3 py-2 print:hidden">
            <option value="">Select a patient</option>
            {patients.map((patient) => <option key={patient.id} value={patient.id}>{patient.firstName} {patient.lastName || ''}</option>)}
          </select>
          {summary && <p className="hidden print:block text-lg font-semibold">{summary.patient.firstName} {summary.patient.lastName}</p>}
        </section>

        {!patientId && <div className="rounded-xl bg-white p-8 text-slate-600 shadow-sm">Choose a patient to generate their report.</div>}
        {loading && <div className="rounded-xl bg-white p-8 text-slate-600 shadow-sm">Building comparison…</div>}
        {error && <div className="rounded-xl border border-red-200 bg-red-50 p-5 text-red-800">{error}</div>}
        {summary && !loading && <>
          <header className="mb-6 rounded-xl bg-white p-6 shadow-sm print:shadow-none">
            <h2 className="text-2xl font-bold text-slate-900">Blood report summary</h2>
            <p className="mt-1 text-slate-700"><strong>Patient:</strong> {summary.patient.firstName} {summary.patient.lastName}</p>
            <p className="text-sm text-slate-600">Reporting period: {date(summary.periodStart)} – {date(summary.periodEnd)} · Generated {date(new Date().toISOString())}</p>
          </header>

          {summary.reports.length === 0 ? <section className="rounded-xl bg-white p-8 shadow-sm"><h3 className="text-lg font-semibold text-slate-900">No extractable blood results found</h3><p className="mt-2 text-slate-600">{summary.candidateReportCount > 0 ? 'Reports were found, but their OCR text did not contain supported lab values. Check the uploaded report or its OCR extraction.' : 'No blood/lab reports dated within the last 90 days were found.'}</p></section> : <>
            <section className="mb-6 rounded-xl bg-white p-6 shadow-sm print:shadow-none">
              <h3 className="text-lg font-semibold text-slate-900">Key findings</h3>
              <ul className="mt-3 space-y-3">
                {summary.keyFindings.map((finding, index) => <li key={index} className={`rounded-lg border p-3 text-sm ${finding.severity === 'attention' ? 'border-amber-200 bg-amber-50 text-amber-950' : finding.severity === 'change' ? 'border-blue-200 bg-blue-50 text-blue-950' : 'border-slate-200 bg-slate-50 text-slate-700'}`}>{finding.text}</li>)}
              </ul>
              <p className="mt-4 text-xs text-slate-500">This summary is derived from uploaded OCR text. It highlights reported ranges and numerical changes; it is not a diagnosis or a substitute for clinical interpretation.</p>
            </section>

            <section className="mb-6 overflow-hidden rounded-xl bg-white shadow-sm print:shadow-none">
              <div className="border-b border-slate-200 p-6"><h3 className="text-lg font-semibold text-slate-900">Results by test</h3><p className="text-sm text-slate-600">Values are ordered oldest to newest. Comparisons are made only when the units match.</p></div>
              <div className="overflow-x-auto"><table className="min-w-full divide-y divide-slate-200 text-sm"><thead className="bg-slate-50 text-left text-slate-600"><tr><th className="px-5 py-3 font-medium">Test</th><th className="px-5 py-3 font-medium">Results</th><th className="px-5 py-3 font-medium">90-day change</th></tr></thead><tbody className="divide-y divide-slate-100">{summary.comparisons.map((comparison) => <tr key={comparison.metric}><td className="whitespace-nowrap px-5 py-4 font-medium text-slate-900">{comparison.label}</td><td className="px-5 py-4"><div className="flex flex-wrap gap-2">{comparison.results.map((result) => <a key={`${result.reportId}-${result.date}`} href={result.documentPath || undefined} target={result.documentPath ? '_blank' : undefined} rel="noreferrer" className={`rounded-md px-2 py-1 ${result.status === 'high' || result.status === 'low' ? 'bg-amber-100 text-amber-900' : 'bg-slate-100 text-slate-800'} ${result.documentPath ? 'hover:underline' : ''}`}>{date(result.date)}: {value(result)}{result.status === 'high' ? ' ↑' : result.status === 'low' ? ' ↓' : ''}</a>)}</div></td><td className="px-5 py-4 text-slate-700">{comparison.change === null ? 'Not comparable' : `${comparison.change > 0 ? '+' : ''}${comparison.change.toFixed(2)}${comparison.unit ? ` ${comparison.unit}` : ''} (${comparison.direction})`}</td></tr>)}</tbody></table></div>
            </section>

            <section className="rounded-xl bg-white p-6 shadow-sm print:shadow-none"><h3 className="text-lg font-semibold text-slate-900">Reports included</h3><ul className="mt-3 divide-y divide-slate-100">{summary.reports.map((report) => <li key={report.id} className="flex items-center justify-between gap-3 py-3 text-sm"><span>{date(report.date)} · {report.source}</span><span className="text-slate-500">{report.results.length} extracted test{report.results.length === 1 ? '' : 's'}</span></li>)}</ul></section>
          </>}
        </>}
      </div>
    </main>
  );
}

export default function BloodSummaryPage() {
  return (
    <Suspense fallback={<div className="min-h-screen grid place-items-center text-gray-600">Loading…</div>}>
      <BloodSummaryContent />
    </Suspense>
  );
}
