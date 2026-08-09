export type RangeStatus = 'low' | 'normal' | 'high' | 'unknown';

export interface LabResult {
  metric: string;
  label: string;
  value: number;
  unit: string | null;
  referenceLow: number | null;
  referenceHigh: number | null;
  status: RangeStatus;
}

export interface BloodReportInput {
  id: string;
  date: Date;
  source: string;
  documentPath?: string;
  ocrText?: string;
}

export interface BloodReport extends BloodReportInput {
  results: LabResult[];
}

export interface MetricComparison {
  metric: string;
  label: string;
  unit: string | null;
  results: Array<LabResult & { reportId: string; date: Date; source: string; documentPath?: string }>;
  change: number | null;
  changePercent: number | null;
  direction: 'increased' | 'decreased' | 'unchanged' | 'not-comparable';
}

export interface KeyFinding {
  severity: 'attention' | 'change' | 'information';
  text: string;
}

const METRICS: Array<{ metric: string; label: string; aliases: string[] }> = [
  { metric: 'hemoglobin', label: 'Hemoglobin', aliases: ['haemoglobin', 'hemoglobin', 'hb'] },
  { metric: 'total_wbc', label: 'Total WBC', aliases: ['total leukocyte count', 'total wbc count', 'white blood cell count', 'wbc count', 'wbc', 'tlc'] },
  { metric: 'rbc', label: 'RBC', aliases: ['red blood cell count', 'rbc count', 'rbc'] },
  { metric: 'hematocrit', label: 'Hematocrit (PCV)', aliases: ['hematocrit', 'packed cell volume', 'pcv'] },
  { metric: 'platelets', label: 'Platelets', aliases: ['platelet count', 'platelets'] },
  { metric: 'mcv', label: 'MCV', aliases: ['mean corpuscular volume', 'mcv'] },
  { metric: 'mch', label: 'MCH', aliases: ['mean corpuscular hemoglobin', 'mch'] },
  { metric: 'mchc', label: 'MCHC', aliases: ['mean corpuscular hemoglobin concentration', 'mchc'] },
  { metric: 'rdw', label: 'RDW', aliases: ['red cell distribution width', 'rdw'] },
  { metric: 'esr', label: 'ESR', aliases: ['erythrocyte sedimentation rate', 'esr'] },
  { metric: 'fasting_glucose', label: 'Fasting glucose', aliases: ['fasting blood sugar', 'fasting glucose', 'fbs'] },
  { metric: 'postprandial_glucose', label: 'Post-prandial glucose', aliases: ['post prandial blood sugar', 'postprandial glucose', 'ppbs'] },
  { metric: 'hba1c', label: 'HbA1c', aliases: ['glycated hemoglobin', 'hba1c', 'hb a1c'] },
  { metric: 'urea', label: 'Urea', aliases: ['blood urea', 'urea'] },
  { metric: 'creatinine', label: 'Creatinine', aliases: ['serum creatinine', 'creatinine'] },
  { metric: 'uric_acid', label: 'Uric acid', aliases: ['serum uric acid', 'uric acid'] },
  { metric: 'sodium', label: 'Sodium', aliases: ['serum sodium', 'sodium'] },
  { metric: 'potassium', label: 'Potassium', aliases: ['serum potassium', 'potassium'] },
  { metric: 'calcium', label: 'Calcium', aliases: ['serum calcium', 'calcium'] },
  { metric: 'alt', label: 'ALT (SGPT)', aliases: ['alanine aminotransferase', 'sgpt', 'alt'] },
  { metric: 'ast', label: 'AST (SGOT)', aliases: ['aspartate aminotransferase', 'sgot', 'ast'] },
  { metric: 'alp', label: 'Alkaline phosphatase', aliases: ['alkaline phosphatase', 'alp'] },
  { metric: 'bilirubin_total', label: 'Total bilirubin', aliases: ['total bilirubin'] },
  { metric: 'albumin', label: 'Albumin', aliases: ['serum albumin', 'albumin'] },
  { metric: 'total_cholesterol', label: 'Total cholesterol', aliases: ['total cholesterol', 'cholesterol total'] },
  { metric: 'triglycerides', label: 'Triglycerides', aliases: ['serum triglycerides', 'triglycerides'] },
  { metric: 'hdl', label: 'HDL cholesterol', aliases: ['hdl cholesterol', 'hdl'] },
  { metric: 'ldl', label: 'LDL cholesterol', aliases: ['ldl cholesterol', 'ldl'] },
  { metric: 'tsh', label: 'TSH', aliases: ['thyroid stimulating hormone', 'serum tsh', 'tsh'] },
  { metric: 't3', label: 'T3', aliases: ['triiodothyronine', 'total t3', 't3'] },
  { metric: 't4', label: 'T4', aliases: ['thyroxine', 'total t4', 't4'] },
  { metric: 'vitamin_d', label: 'Vitamin D', aliases: ['25 oh vitamin d', 'vitamin d'] },
  { metric: 'vitamin_b12', label: 'Vitamin B12', aliases: ['vitamin b12', 'b12'] },
  { metric: 'ferritin', label: 'Ferritin', aliases: ['serum ferritin', 'ferritin'] },
  { metric: 'crp', label: 'CRP', aliases: ['c reactive protein', 'crp'] },
];

const numberPattern = '(-?\\d+(?:[,.]\\d+)?)';
const rangePattern = new RegExp(`${numberPattern}\\s*(?:-|–|—|to)\\s*${numberPattern}`, 'i');

function normaliseUnit(unit: string | null): string | null {
  return unit?.toLowerCase().replace(/[\s.]/g, '').replace('μ', 'u').replace('µ', 'u') || null;
}

function valueStatus(value: number, low: number | null, high: number | null): RangeStatus {
  if (low === null || high === null) return 'unknown';
  if (value < low) return 'low';
  if (value > high) return 'high';
  return 'normal';
}

function titleCase(text: string): string {
  return text.replace(/\b\w/g, (char) => char.toUpperCase());
}

/**
 * Extracts a conservative subset of common blood-test values from OCR output.
 * Only recognised metrics are included, avoiding accidental capture of dates or IDs.
 */
export function parseBloodResults(ocrText = ''): LabResult[] {
  const results = new Map<string, LabResult>();
  const lines = ocrText.replace(/\r/g, '').split('\n');

  for (const rawLine of lines) {
    const line = rawLine.replace(/\s+/g, ' ').trim();
    if (!line || line.length > 180) continue;
    const lowerLine = line.toLowerCase();

    for (const definition of METRICS) {
      const alias = [...definition.aliases].sort((a, b) => b.length - a.length)
        .find((candidate) => new RegExp(`(^|[^a-z0-9])${candidate.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z0-9]|$)`, 'i').test(lowerLine));
      if (!alias) continue;

      const aliasIndex = lowerLine.indexOf(alias);
      const remainder = line.slice(aliasIndex + alias.length)
        .replace(/^\s*[:=\-–—]?\s*/, '');
      const valueMatch = remainder.match(new RegExp(`^${numberPattern}`));
      if (!valueMatch) continue;

      const value = Number(valueMatch[1].replace(',', '.'));
      if (!Number.isFinite(value)) continue;
      const afterValue = remainder.slice(valueMatch[0].length).trim();
      const unitMatch = afterValue.match(/^([a-zA-Zμµ%][a-zA-Z0-9μµ/%^.-]*)/);
      const rangeMatch = afterValue.match(rangePattern);
      const referenceLow = rangeMatch ? Number(rangeMatch[1].replace(',', '.')) : null;
      const referenceHigh = rangeMatch ? Number(rangeMatch[2].replace(',', '.')) : null;
      const unit = unitMatch?.[1] || null;

      // Keep the first occurrence: reports frequently repeat a result in a summary.
      if (!results.has(definition.metric)) {
        results.set(definition.metric, {
          metric: definition.metric,
          label: definition.label || titleCase(alias),
          value,
          unit,
          referenceLow: Number.isFinite(referenceLow) ? referenceLow : null,
          referenceHigh: Number.isFinite(referenceHigh) ? referenceHigh : null,
          status: valueStatus(value, referenceLow, referenceHigh),
        });
      }
      break;
    }
  }

  return [...results.values()];
}

export function buildBloodReportSummary(inputs: BloodReportInput[]) {
  const reports: BloodReport[] = inputs
    .map((input) => ({ ...input, results: parseBloodResults(input.ocrText) }))
    .filter((report) => report.results.length > 0)
    .sort((a, b) => b.date.getTime() - a.date.getTime());

  const metrics = new Map<string, MetricComparison>();
  for (const report of reports) {
    for (const result of report.results) {
      const existing = metrics.get(result.metric) || {
        metric: result.metric,
        label: result.label,
        unit: result.unit,
        results: [],
        change: null,
        changePercent: null,
        direction: 'not-comparable' as const,
      };
      existing.results.push({ ...result, reportId: report.id, date: report.date, source: report.source, documentPath: report.documentPath });
      metrics.set(result.metric, existing);
    }
  }

  const comparisons = [...metrics.values()].map((comparison) => {
    comparison.results.sort((a, b) => a.date.getTime() - b.date.getTime());
    const oldest = comparison.results[0];
    const newest = comparison.results[comparison.results.length - 1];
    if (comparison.results.length > 1 && normaliseUnit(oldest.unit) === normaliseUnit(newest.unit)) {
      const change = newest.value - oldest.value;
      comparison.change = change;
      comparison.changePercent = oldest.value === 0 ? null : (change / Math.abs(oldest.value)) * 100;
      comparison.direction = Math.abs(change) < 0.000001 ? 'unchanged' : change > 0 ? 'increased' : 'decreased';
    }
    return comparison;
  }).sort((a, b) => a.label.localeCompare(b.label));

  const keyFindings: KeyFinding[] = [];
  for (const comparison of comparisons) {
    const latest = comparison.results[comparison.results.length - 1];
    const unit = latest.unit ? ` ${latest.unit}` : '';
    if (latest.status === 'high' || latest.status === 'low') {
      const boundary = latest.status === 'high' ? `above ${latest.referenceHigh}` : `below ${latest.referenceLow}`;
      keyFindings.push({
        severity: 'attention',
        text: `${comparison.label} was ${latest.value}${unit} on ${formatDate(latest.date)}, ${boundary}${unit} on that lab's stated range.`,
      });
    }
    if (comparison.direction !== 'not-comparable' && comparison.direction !== 'unchanged') {
      keyFindings.push({
        severity: 'change',
        text: `${comparison.label} ${comparison.direction} from ${comparison.results[0].value}${unit} on ${formatDate(comparison.results[0].date)} to ${latest.value}${unit} on ${formatDate(latest.date)}.`,
      });
    }
  }

  if (keyFindings.length === 0 && reports.length > 0) {
    keyFindings.push({ severity: 'information', text: 'No values outside a stated laboratory range or comparable changes were detected in the extracted results.' });
  }

  return { reports, comparisons, keyFindings };
}

export function formatDate(date: Date): string {
  return new Intl.DateTimeFormat('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }).format(date);
}
