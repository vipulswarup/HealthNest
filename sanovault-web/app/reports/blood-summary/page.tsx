'use client';

import Image from 'next/image';
import Link from 'next/link';
import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useSession } from '@/lib/auth/client';

interface ResultPoint {
  value: number;
  unit: string | null;
  status: string;
  date: string;
  reportId: string;
  documentPath?: string;
}

interface Comparison {
  metric: string;
  label: string;
  panel: string;
  unit: string | null;
  direction: string;
  change: number | null;
  changePercent: number | null;
  results: ResultPoint[];
}

interface PanelBlock {
  panel: string;
  label: string;
  comparisons: Comparison[];
}

interface SummaryResponse {
  patient: { id: string; firstName: string; lastName: string };
  periodStart: string;
  periodEnd: string;
  lookbackDays?: number;
  candidateReportCount: number;
  reports: Array<{ id: string; date: string; source: string; documentPath?: string; results: Array<{ metric: string }> }>;
  comparisons: Comparison[];
  panels: PanelBlock[];
  keyFindings: Array<{ severity: string; text: string }>;
}

const formatDate = (value: string) =>
  new Intl.DateTimeFormat('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(value));

const formatValue = (result: { value: number; unit: string | null }) =>
  `${result.value}${result.unit ? ` ${result.unit}` : ''}`;

function Sparkline({ values }: { values: number[] }) {
  if (values.length < 2) {
    return <span className="text-xs text-slate-400">Need 2+ points</span>;
  }
  const width = 120;
  const height = 36;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const points = values
    .map((value, index) => {
      const x = (index / (values.length - 1)) * width;
      const y = height - ((value - min) / span) * (height - 6) - 3;
      return `${x},${y}`;
    })
    .join(' ');
  const rising = values[values.length - 1] >= values[0];
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="overflow-visible" aria-hidden="true">
      <polyline
        fill="none"
        stroke={rising ? '#b45309' : '#0175C2'}
        strokeWidth="2"
        points={points}
      />
      {values.map((value, index) => {
        const x = (index / (values.length - 1)) * width;
        const y = height - ((value - min) / span) * (height - 6) - 3;
        return <circle key={index} cx={x} cy={y} r="2.5" fill={rising ? '#b45309' : '#0175C2'} />;
      })}
    </svg>
  );
}

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
    if (!session?.user?.id) return;
    fetch('/api/patients')
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error('Could not load patients'))))
      .then(setPatients)
      .catch((err) => setError(err.message));
  }, [session?.user?.id]);

  useEffect(() => {
    if (!patientId || !session?.user?.id) return;
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
    return () => {
      cancelled = true;
    };
  }, [patientId, session?.user?.id]);

  const selectPatient = (id: string) => router.push(`/reports/blood-summary?patientId=${id}`);

  if (status === 'loading' || !session) {
    return <div className="min-h-screen grid place-items-center text-gray-600">Loading…</div>;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <nav className="bg-white shadow-lg print:hidden">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
          <div className="flex items-center space-x-3">
            <Link href="/dashboard">
              <Image src="/logo.png" alt="SanoVault Logo" width={40} height={40} className="rounded-full cursor-pointer" />
            </Link>
            <Link href="/dashboard">
              <h1 className="text-xl font-bold text-gray-900 cursor-pointer">SanoVault</h1>
            </Link>
          </div>
          <Link href="/health-records" className="text-sm text-gray-700 hover:text-[#0175C2]">
            Back to Health Records
          </Link>
        </div>
      </nav>

      <main className="mx-auto max-w-6xl px-4 py-8 sm:px-8">
        <div className="mb-6 flex flex-wrap items-center justify-between gap-4 print:hidden">
          <div>
            <h1 className="text-3xl font-bold text-slate-900">Blood work summary</h1>
            <p className="mt-1 text-slate-600">
              90-day trends for Blood, Iron, Kidney, Liver, Cholesterol, Thyroid, and related panels.
            </p>
          </div>
          <button
            onClick={() => window.print()}
            disabled={!summary}
            className="rounded-lg bg-[#0175C2] px-4 py-2 font-medium text-white disabled:cursor-not-allowed disabled:bg-slate-300"
          >
            Print / Save PDF
          </button>
        </div>

        <section className="mb-6 rounded-xl bg-white p-5 shadow-sm print:shadow-none">
          <label htmlFor="patient" className="mb-2 block text-sm font-medium text-slate-700">
            Patient
          </label>
          <select
            id="patient"
            value={patientId || ''}
            onChange={(event) => selectPatient(event.target.value)}
            className="w-full max-w-md rounded-lg border border-slate-300 px-3 py-2 print:hidden"
          >
            <option value="">Select a patient</option>
            {patients.map((patient) => (
              <option key={patient.id} value={patient.id}>
                {patient.firstName} {patient.lastName || ''}
              </option>
            ))}
          </select>
          {summary && (
            <p className="hidden print:block text-lg font-semibold">
              {summary.patient.firstName} {summary.patient.lastName}
            </p>
          )}
        </section>

        {!patientId && (
          <div className="rounded-xl bg-white p-8 text-slate-600 shadow-sm">
            Choose a patient to generate their report.
          </div>
        )}
        {loading && (
          <div className="rounded-xl bg-white p-8 text-slate-600 shadow-sm">Building 90-day comparison…</div>
        )}
        {error && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-5 text-red-800">{error}</div>
        )}

        {summary && !loading && (
          <>
            <header className="mb-6 rounded-xl bg-white p-6 shadow-sm print:shadow-none">
              <h2 className="text-2xl font-bold text-slate-900">Blood work summary</h2>
              <p className="mt-1 text-slate-700">
                <strong>Patient:</strong> {summary.patient.firstName} {summary.patient.lastName}
              </p>
              <p className="text-sm text-slate-600">
                Reporting period: {formatDate(summary.periodStart)} – {formatDate(summary.periodEnd)} · Generated{' '}
                {formatDate(new Date().toISOString())}
              </p>
              <p className="mt-1 text-sm text-slate-500">
                {summary.reports.length} report{summary.reports.length === 1 ? '' : 's'} with extractable values ·{' '}
                {summary.comparisons.length} tracked metric{summary.comparisons.length === 1 ? '' : 's'}
              </p>
            </header>

            {summary.reports.length === 0 ? (
              <section className="rounded-xl bg-white p-8 shadow-sm">
                <h3 className="text-lg font-semibold text-slate-900">No extractable blood results found</h3>
                <p className="mt-2 text-slate-600">
                  {summary.candidateReportCount > 0
                    ? 'Lab reports were found in the last 90 days, but OCR text did not contain supported values. Re-process those documents or upload clearer copies.'
                    : 'No blood/lab reports dated within the last 90 days were found.'}
                </p>
              </section>
            ) : (
              <>
                <section className="mb-6 rounded-xl bg-white p-6 shadow-sm print:shadow-none">
                  <h3 className="text-lg font-semibold text-slate-900">Key findings</h3>
                  <ul className="mt-3 space-y-3">
                    {summary.keyFindings.map((finding, index) => (
                      <li
                        key={index}
                        className={`rounded-lg border p-3 text-sm ${
                          finding.severity === 'attention'
                            ? 'border-amber-200 bg-amber-50 text-amber-950'
                            : finding.severity === 'change'
                              ? 'border-blue-200 bg-blue-50 text-blue-950'
                              : 'border-slate-200 bg-slate-50 text-slate-700'
                        }`}
                      >
                        {finding.text}
                      </li>
                    ))}
                  </ul>
                  <p className="mt-4 text-xs text-slate-500">
                    Derived from uploaded OCR text for clinician review. Not a diagnosis.
                  </p>
                </section>

                {(summary.panels?.length ? summary.panels : [{ panel: 'other', label: 'Results', comparisons: summary.comparisons }]).map((panel) => (
                  <section key={panel.panel} className="mb-6 overflow-hidden rounded-xl bg-white shadow-sm print:shadow-none">
                    <div className="border-b border-slate-200 p-5">
                      <h3 className="text-lg font-semibold text-slate-900">{panel.label}</h3>
                      <p className="text-sm text-slate-600">Oldest to newest over the last 90 days.</p>
                    </div>
                    <div className="overflow-x-auto">
                      <table className="min-w-full divide-y divide-slate-200 text-sm">
                        <thead className="bg-slate-50 text-left text-slate-600">
                          <tr>
                            <th className="px-5 py-3 font-medium">Test</th>
                            <th className="px-5 py-3 font-medium">Trend</th>
                            <th className="px-5 py-3 font-medium">Results</th>
                            <th className="px-5 py-3 font-medium">90-day change</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                          {panel.comparisons.map((comparison) => (
                            <tr key={comparison.metric}>
                              <td className="whitespace-nowrap px-5 py-4 font-medium text-slate-900">
                                {comparison.label}
                              </td>
                              <td className="px-5 py-4">
                                <Sparkline values={comparison.results.map((item) => item.value)} />
                              </td>
                              <td className="px-5 py-4">
                                <div className="flex flex-wrap gap-2">
                                  {comparison.results.map((result) => (
                                    <Link
                                      key={`${result.reportId}-${result.date}`}
                                      href={result.documentPath || `/health-records/${result.reportId}`}
                                      className={`rounded-md px-2 py-1 hover:underline ${
                                        result.status === 'high' || result.status === 'low'
                                          ? 'bg-amber-100 text-amber-900'
                                          : 'bg-slate-100 text-slate-800'
                                      }`}
                                    >
                                      {formatDate(result.date)}: {formatValue(result)}
                                      {result.status === 'high' ? ' ↑' : result.status === 'low' ? ' ↓' : ''}
                                    </Link>
                                  ))}
                                </div>
                              </td>
                              <td className="px-5 py-4 text-slate-700">
                                {comparison.change === null
                                  ? 'Not comparable'
                                  : `${comparison.change > 0 ? '+' : ''}${comparison.change.toFixed(2)}${
                                      comparison.unit ? ` ${comparison.unit}` : ''
                                    } (${comparison.direction})`}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </section>
                ))}

                <section className="rounded-xl bg-white p-6 shadow-sm print:shadow-none">
                  <h3 className="text-lg font-semibold text-slate-900">Reports included</h3>
                  <ul className="mt-3 divide-y divide-slate-100">
                    {summary.reports.map((report) => (
                      <li key={report.id} className="flex items-center justify-between gap-3 py-3 text-sm">
                        <Link href={report.documentPath || `/health-records/${report.id}`} className="text-[#0175C2] hover:underline">
                          {formatDate(report.date)} · {report.source}
                        </Link>
                        <span className="text-slate-500">
                          {report.results.length} extracted test{report.results.length === 1 ? '' : 's'}
                        </span>
                      </li>
                    ))}
                  </ul>
                </section>
              </>
            )}
          </>
        )}
      </main>
    </div>
  );
}

export default function BloodSummaryPage() {
  return (
    <Suspense fallback={<div className="min-h-screen grid place-items-center text-gray-600">Loading…</div>}>
      <BloodSummaryContent />
    </Suspense>
  );
}
