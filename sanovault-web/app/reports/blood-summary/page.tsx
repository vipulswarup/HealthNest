'use client';

import Link from 'next/link';
import { Suspense, useCallback, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useSession } from '@/lib/auth/client';
import { LabResultsEditor } from '@/components/lab/LabResultsEditor';
import { LabResult } from '@/lib/reports/blood-summary';
import AppNav from '@/components/layout/AppNav';

interface ResultPoint {
  metric: string;
  label: string;
  panel: string;
  value: number;
  unit: string | null;
  referenceLow: number | null;
  referenceHigh: number | null;
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

interface SummaryReport {
  id: string;
  date: string;
  source: string;
  documentPath?: string;
  useManualResults?: boolean;
  results: LabResult[];
}

interface SummaryResponse {
  patient: { id: string; firstName: string; lastName: string };
  periodStart: string;
  periodEnd: string;
  lookbackDays?: number;
  candidateReportCount: number;
  reports: SummaryReport[];
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
  const [editingReport, setEditingReport] = useState<SummaryReport | null>(null);
  const [draftResults, setDraftResults] = useState<LabResult[]>([]);
  const [savingEdits, setSavingEdits] = useState(false);
  const [editError, setEditError] = useState('');
  const editDialogRef = useRef<HTMLDivElement>(null);
  const editCloseRef = useRef<HTMLButtonElement>(null);
  const closeEditor = useCallback(() => {
    if (savingEdits) return;
    setEditingReport(null);
    setDraftResults([]);
    setEditError('');
  }, [savingEdits]);

  useEffect(() => {
    if (!editingReport) return;
    const previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    editCloseRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !savingEdits) {
        event.preventDefault();
        closeEditor();
        return;
      }
      if (event.key !== 'Tab' || !editDialogRef.current) return;
      const focusable = Array.from(editDialogRef.current.querySelectorAll<HTMLElement>(
        'button:not([disabled]), input:not([disabled]), select:not([disabled]), [href], [tabindex]:not([tabindex="-1"])',
      ));
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = previousOverflow;
      previouslyFocused?.focus();
    };
  }, [closeEditor, editingReport, savingEdits]);

  useEffect(() => {
    if (status !== 'loading' && !session) router.replace('/auth/signin');
  }, [session, status, router]);

  useEffect(() => {
    if (!session?.user?.id) return;
    fetch('/api/patients')
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error('Could not load patients'))))
      .then(setPatients)
      .catch((err) => setError(err.message));
  }, [session?.user?.id]);

  const loadSummary = async (selectedPatientId: string) => {
    setLoading(true);
    setError('');
    try {
      const response = await fetch(`/api/reports/blood-summary?patientId=${encodeURIComponent(selectedPatientId)}`);
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || 'Could not generate the report');
      setSummary(payload);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not generate the report');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!patientId || !session?.user?.id) return;
    let cancelled = false;
    async function run() {
      setLoading(true);
      setError('');
      try {
        const response = await fetch(`/api/reports/blood-summary?patientId=${encodeURIComponent(patientId!)}`);
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.error || 'Could not generate the report');
        if (!cancelled) setSummary(payload);
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Could not generate the report');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void run();
    return () => {
      cancelled = true;
    };
  }, [patientId, session?.user?.id]);

  const selectPatient = (id: string) => router.push(`/reports/blood-summary?patientId=${id}`);

  const openEditor = (report: SummaryReport) => {
    setEditingReport(report);
    setDraftResults(report.results || []);
    setEditError('');
  };

  const saveManualResults = async (clearOverride = false) => {
    if (!editingReport || !patientId) return;
    setSavingEdits(true);
    setEditError('');
    try {
      const currentRes = await fetch(`/api/health-records/${editingReport.id}`);
      const current = await currentRes.json();
      if (!currentRes.ok) throw new Error(current.error || 'Could not load health record');

      const nextData = { ...(current.data || {}) };
      if (clearOverride) {
        delete nextData.labResultsManual;
        delete nextData.labResults;
        delete nextData.labResultsEditedAt;
      } else {
        nextData.labResultsManual = true;
        nextData.labResults = draftResults;
        nextData.labResultsEditedAt = new Date().toISOString();
      }

      const saveRes = await fetch(`/api/health-records/${editingReport.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: nextData }),
      });
      const saved = await saveRes.json();
      if (!saveRes.ok) throw new Error(saved.error || 'Could not save lab values');

      setEditingReport(null);
      setDraftResults([]);
      await loadSummary(patientId);
    } catch (err) {
      setEditError(err instanceof Error ? err.message : 'Could not save lab values');
    } finally {
      setSavingEdits(false);
    }
  };

  if (status === 'loading' || !session) {
    return <div className="min-h-screen grid place-items-center text-gray-600">Loading…</div>;
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <AppNav />

      <main className="mx-auto max-w-6xl px-4 py-8 sm:px-8">
        <div className="mb-6 flex flex-wrap items-center justify-between gap-4 print:hidden">
          <div>
            <Link href="/health-records" className="mb-3 inline-block text-sm font-medium text-[#0175C2] hover:underline">
              ← Back to health records
            </Link>
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
            onChange={(e) => selectPatient(e.target.value)}
            className="w-full max-w-md rounded-lg border border-slate-300 px-3 py-2"
          >
            <option value="">Select a patient</option>
            {patients.map((patient) => (
              <option key={patient.id} value={patient.id}>
                {patient.firstName} {patient.lastName || ''}
              </option>
            ))}
          </select>
        </section>

        {error && (
          <div className="mb-6 rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-rose-800">{error}</div>
        )}

        {!patientId && (
          <div className="rounded-xl bg-white p-8 text-center text-slate-600 shadow-sm">
            Choose a patient to generate the blood work summary.
          </div>
        )}

        {patientId && loading && (
          <div className="rounded-xl bg-white p-8 text-center text-slate-600 shadow-sm">Building summary…</div>
        )}

        {patientId && !loading && summary && (
          <>
            {summary.comparisons.length === 0 ? (
              <div className="rounded-xl bg-white p-8 text-center text-slate-600 shadow-sm">
                No extractable lab values found in the last {summary.lookbackDays || 90} days.
              </div>
            ) : (
              <>
                <section className="mb-6 rounded-xl bg-white p-6 shadow-sm print:shadow-none">
                  <h2 className="text-lg font-semibold text-slate-900">
                    {summary.patient.firstName} {summary.patient.lastName}
                  </h2>
                  <p className="mt-1 text-sm text-slate-600">
                    {formatDate(summary.periodStart)} – {formatDate(summary.periodEnd)} · {summary.candidateReportCount} report
                    {summary.candidateReportCount === 1 ? '' : 's'} considered
                  </p>
                  <h3 className="mt-5 text-base font-semibold text-slate-900">Key findings</h3>
                  <ul className="mt-3 space-y-2">
                    {summary.keyFindings.map((finding, index) => (
                      <li
                        key={index}
                        className={`rounded-md px-3 py-2 text-sm ${
                          finding.severity === 'attention'
                            ? 'bg-amber-50 text-amber-950'
                            : finding.severity === 'change'
                              ? 'bg-sky-50 text-sky-950'
                              : 'bg-slate-50 text-slate-700'
                        }`}
                      >
                        {finding.text}
                      </li>
                    ))}
                  </ul>
                  <p className="mt-4 text-xs text-slate-500">
                    Derived from uploaded OCR text for clinician review. Not a diagnosis. You can correct values per report below.
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
                                      key={`${result.reportId}-${result.date}-${result.value}`}
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
                                  ? 'Not comparable (mixed/missing units)'
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

                <section className="rounded-xl bg-white p-6 shadow-sm print:shadow-none print:hidden">
                  <h3 className="text-lg font-semibold text-slate-900">Reports included</h3>
                  <p className="mt-1 text-sm text-slate-600">
                    Edit values only when auto-extraction is wrong. Unedited reports keep using OCR.
                  </p>
                  <ul className="mt-3 divide-y divide-slate-100">
                    {summary.reports.map((report) => (
                      <li key={report.id} className="flex flex-wrap items-center justify-between gap-3 py-3 text-sm">
                        <div>
                          <Link href={report.documentPath || `/health-records/${report.id}`} className="text-[#0175C2] hover:underline">
                            {formatDate(report.date)} · {report.source}
                          </Link>
                          <div className="mt-1 text-slate-500">
                            {report.results.length} extracted test{report.results.length === 1 ? '' : 's'}
                            {report.useManualResults ? ' · manual override' : ''}
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => openEditor(report)}
                          className="rounded-md border border-slate-300 px-3 py-1.5 text-slate-700 hover:bg-slate-50"
                        >
                          Edit values
                        </button>
                      </li>
                    ))}
                  </ul>
                </section>
              </>
            )}
          </>
        )}
      </main>

      {editingReport && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-slate-900/40 p-4 sm:items-center print:hidden" onMouseDown={(event) => {
          if (event.target === event.currentTarget && !savingEdits) closeEditor();
        }}>
          <div ref={editDialogRef} role="dialog" aria-modal="true" aria-labelledby="edit-lab-values-title" tabIndex={-1} className="max-h-[90vh] w-full max-w-4xl overflow-y-auto rounded-xl bg-white p-5 shadow-xl">
            <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 id="edit-lab-values-title" className="text-lg font-semibold text-slate-900">Edit lab values</h2>
                <p className="mt-1 text-sm text-slate-600">
                  {formatDate(editingReport.date)} · {editingReport.source}
                </p>
              </div>
              <button ref={editCloseRef} type="button" onClick={closeEditor} className="min-h-11 rounded-md px-3 text-sm text-slate-600 hover:bg-slate-100">
                Close
              </button>
            </div>
            {editError && (
              <div className="mb-3 rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-800">
                {editError}
              </div>
            )}
            <LabResultsEditor results={draftResults} onChange={setDraftResults} disabled={savingEdits} />
            <div className="mt-5 flex flex-wrap gap-2">
              <button
                type="button"
                disabled={savingEdits}
                onClick={() => void saveManualResults(false)}
                className="rounded-lg bg-[#0175C2] px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
              >
                {savingEdits ? 'Saving…' : 'Save corrections'}
              </button>
              {editingReport.useManualResults && (
                <button
                  type="button"
                  disabled={savingEdits}
                  onClick={() => void saveManualResults(true)}
                  className="rounded-lg border border-slate-300 px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50"
                >
                  Revert to auto-extract
                </button>
              )}
              <button
                type="button"
                disabled={savingEdits}
                onClick={closeEditor}
                className="rounded-lg border border-slate-300 px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
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
