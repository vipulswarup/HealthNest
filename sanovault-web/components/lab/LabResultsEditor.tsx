'use client';

import { useEffect, useState } from 'react';
import {
  LAB_METRIC_OPTIONS,
  LabResult,
  valueStatus,
} from '@/lib/reports/blood-summary';

type DraftRow = {
  localId: string;
  metric: string;
  value: string;
  unit: string;
  referenceLow: string;
  referenceHigh: string;
};

function toDraft(results: LabResult[]): DraftRow[] {
  return results.map((result, index) => ({
    localId: `${result.metric}-${index}`,
    metric: result.metric,
    value: String(result.value),
    unit: result.unit || '',
    referenceLow: result.referenceLow === null || result.referenceLow === undefined ? '' : String(result.referenceLow),
    referenceHigh: result.referenceHigh === null || result.referenceHigh === undefined ? '' : String(result.referenceHigh),
  }));
}

function parseOptionalNumber(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const n = Number(trimmed.replace(',', '.'));
  return Number.isFinite(n) ? n : null;
}

function toLabResults(drafts: DraftRow[]): LabResult[] {
  const byMetric = new Map<string, LabResult>();
  for (const draft of drafts) {
    const option = LAB_METRIC_OPTIONS.find((item) => item.metric === draft.metric);
    if (!option) continue;
    const value = parseOptionalNumber(draft.value);
    if (value === null) continue;
    const referenceLow = parseOptionalNumber(draft.referenceLow);
    const referenceHigh = parseOptionalNumber(draft.referenceHigh);
    const unit = draft.unit.trim() || null;
    byMetric.set(option.metric, {
      metric: option.metric,
      label: option.label,
      panel: option.panel,
      value,
      unit,
      referenceLow,
      referenceHigh,
      status: valueStatus(value, referenceLow, referenceHigh),
    });
  }
  return [...byMetric.values()];
}

function resultsSignature(results: LabResult[]): string {
  return results
    .map((item) => `${item.metric}:${item.value}:${item.unit}:${item.referenceLow}:${item.referenceHigh}`)
    .join('|');
}

interface LabResultsEditorProps {
  results: LabResult[];
  onChange: (results: LabResult[]) => void;
  disabled?: boolean;
}

export function LabResultsEditor({ results, onChange, disabled = false }: LabResultsEditorProps) {
  const [drafts, setDrafts] = useState<DraftRow[]>(() => toDraft(results));
  const [sourceSignature, setSourceSignature] = useState(() => resultsSignature(results));

  useEffect(() => {
    const nextSignature = resultsSignature(results);
    if (nextSignature !== sourceSignature) {
      setDrafts(toDraft(results));
      setSourceSignature(nextSignature);
    }
  }, [results, sourceSignature]);

  const usedMetrics = new Set(drafts.map((row) => row.metric));
  const availableToAdd = LAB_METRIC_OPTIONS.filter((item) => !usedMetrics.has(item.metric));

  const commit = (next: DraftRow[]) => {
    setDrafts(next);
    const sanitized = toLabResults(next);
    setSourceSignature(resultsSignature(sanitized));
    onChange(sanitized);
  };

  const updateRow = (localId: string, patch: Partial<DraftRow>) => {
    commit(drafts.map((row) => (row.localId === localId ? { ...row, ...patch } : row)));
  };

  const removeRow = (localId: string) => {
    commit(drafts.filter((row) => row.localId !== localId));
  };

  const addRow = () => {
    const nextMetric = availableToAdd[0];
    if (!nextMetric) return;
    commit([
      ...drafts,
      {
        localId: `${nextMetric.metric}-${Date.now()}`,
        metric: nextMetric.metric,
        value: '',
        unit: '',
        referenceLow: '',
        referenceHigh: '',
      },
    ]);
  };

  return (
    <div className="space-y-3">
      <div className="overflow-x-auto rounded-lg border border-slate-200">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50 text-left text-slate-600">
            <tr>
              <th className="px-3 py-2 font-medium">Test</th>
              <th className="px-3 py-2 font-medium">Value</th>
              <th className="px-3 py-2 font-medium">Unit</th>
              <th className="px-3 py-2 font-medium">Ref low</th>
              <th className="px-3 py-2 font-medium">Ref high</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 bg-white">
            {drafts.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-3 py-4 text-slate-500">
                  No lab values yet. Add a test, or keep using auto-extraction.
                </td>
              </tr>
            ) : (
              drafts.map((row) => (
                <tr key={row.localId}>
                  <td className="px-3 py-2">
                    <select
                      value={row.metric}
                      disabled={disabled}
                      onChange={(e) => updateRow(row.localId, { metric: e.target.value })}
                      className="w-full min-w-[10rem] rounded-md border border-slate-300 px-2 py-1.5"
                    >
                      {LAB_METRIC_OPTIONS.filter(
                        (option) => option.metric === row.metric || !usedMetrics.has(option.metric),
                      ).map((option) => (
                        <option key={option.metric} value={option.metric}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="text"
                      inputMode="decimal"
                      value={row.value}
                      disabled={disabled}
                      onChange={(e) => updateRow(row.localId, { value: e.target.value })}
                      className="w-24 rounded-md border border-slate-300 px-2 py-1.5"
                    />
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="text"
                      value={row.unit}
                      disabled={disabled}
                      onChange={(e) => updateRow(row.localId, { unit: e.target.value })}
                      className="w-24 rounded-md border border-slate-300 px-2 py-1.5"
                      placeholder="mg/dL"
                    />
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="text"
                      inputMode="decimal"
                      value={row.referenceLow}
                      disabled={disabled}
                      onChange={(e) => updateRow(row.localId, { referenceLow: e.target.value })}
                      className="w-20 rounded-md border border-slate-300 px-2 py-1.5"
                    />
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="text"
                      inputMode="decimal"
                      value={row.referenceHigh}
                      disabled={disabled}
                      onChange={(e) => updateRow(row.localId, { referenceHigh: e.target.value })}
                      className="w-20 rounded-md border border-slate-300 px-2 py-1.5"
                    />
                  </td>
                  <td className="px-3 py-2 text-right">
                    <button
                      type="button"
                      disabled={disabled}
                      onClick={() => removeRow(row.localId)}
                      className="text-sm text-rose-700 hover:underline disabled:opacity-50"
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      <button
        type="button"
        disabled={disabled || availableToAdd.length === 0}
        onClick={addRow}
        className="rounded-md border border-slate-300 px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
      >
        Add test
      </button>
    </div>
  );
}
