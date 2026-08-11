export type RangeStatus = 'low' | 'normal' | 'high' | 'unknown';

export type LabPanel =
  | 'blood'
  | 'iron'
  | 'kidney'
  | 'liver'
  | 'cholesterol'
  | 'thyroid'
  | 'diabetes'
  | 'vitamins'
  | 'other';

export interface LabResult {
  metric: string;
  label: string;
  panel: LabPanel;
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
  /** When true, use manualResults instead of OCR parse for this report. */
  useManualResults?: boolean;
  manualResults?: LabResult[];
}

export interface BloodReport extends BloodReportInput {
  results: LabResult[];
}

export interface LabMetricOption {
  metric: string;
  label: string;
  panel: LabPanel;
}

export interface MetricComparison {
  metric: string;
  label: string;
  panel: LabPanel;
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

export interface PanelSummary {
  panel: LabPanel;
  label: string;
  comparisons: MetricComparison[];
}

const PANEL_LABELS: Record<LabPanel, string> = {
  blood: 'Blood (CBC)',
  iron: 'Iron studies',
  kidney: 'Kidney',
  liver: 'Liver',
  cholesterol: 'Cholesterol / lipids',
  thyroid: 'Thyroid',
  diabetes: 'Diabetes / glucose',
  vitamins: 'Vitamins & inflammation',
  other: 'Other',
};

const PANEL_ORDER: LabPanel[] = [
  'blood',
  'diabetes',
  'iron',
  'kidney',
  'liver',
  'cholesterol',
  'thyroid',
  'vitamins',
  'other',
];

const METRICS: Array<{ metric: string; label: string; panel: LabPanel; aliases: string[] }> = [
  // Blood / CBC
  { metric: 'hemoglobin', label: 'Hemoglobin', panel: 'blood', aliases: ['haemoglobin', 'hemoglobin', 'hb'] },
  { metric: 'total_wbc', label: 'Total WBC', panel: 'blood', aliases: ['total leukocyte count', 'total wbc count', 'white blood cell count', 'wbc count', 'wbc', 'tlc'] },
  { metric: 'rbc', label: 'RBC', panel: 'blood', aliases: ['red blood cell count', 'rbc count', 'rbc'] },
  { metric: 'hematocrit', label: 'Hematocrit (PCV)', panel: 'blood', aliases: ['hematocrit', 'packed cell volume', 'pcv'] },
  { metric: 'platelets', label: 'Platelets', panel: 'blood', aliases: ['platelet count', 'platelets'] },
  { metric: 'mcv', label: 'MCV', panel: 'blood', aliases: ['mean corpuscular volume', 'mcv'] },
  { metric: 'mch', label: 'MCH', panel: 'blood', aliases: ['mean corpuscular hemoglobin', 'mean corpuscular haemoglobin', 'mch'] },
  { metric: 'mchc', label: 'MCHC', panel: 'blood', aliases: ['mean corpuscular hemoglobin concentration', 'mean corpuscular haemoglobin concentration', 'mchc'] },
  { metric: 'rdw', label: 'RDW', panel: 'blood', aliases: ['red cell distribution width', 'rdw'] },
  { metric: 'mpv', label: 'MPV', panel: 'blood', aliases: ['mean platelet volume', 'mpv'] },
  { metric: 'neutrophils', label: 'Neutrophils', panel: 'blood', aliases: ['neutrophils', 'neutrophil'] },
  { metric: 'lymphocytes', label: 'Lymphocytes', panel: 'blood', aliases: ['lymphocytes', 'lymphocyte'] },
  { metric: 'monocytes', label: 'Monocytes', panel: 'blood', aliases: ['monocytes', 'monocyte'] },
  { metric: 'eosinophils', label: 'Eosinophils', panel: 'blood', aliases: ['eosinophils', 'eosinophil'] },
  { metric: 'basophils', label: 'Basophils', panel: 'blood', aliases: ['basophils', 'basophil'] },
  { metric: 'esr', label: 'ESR', panel: 'blood', aliases: ['erythrocyte sedimentation rate', 'esr'] },

  // Diabetes
  { metric: 'fasting_glucose', label: 'Fasting glucose', panel: 'diabetes', aliases: ['fasting blood sugar', 'fasting plasma glucose', 'fasting glucose', 'fbs', 'fpg'] },
  { metric: 'postprandial_glucose', label: 'Post-prandial glucose', panel: 'diabetes', aliases: ['post prandial blood sugar', 'postprandial glucose', 'ppbs', 'ppg'] },
  { metric: 'hba1c', label: 'HbA1c', panel: 'diabetes', aliases: ['glycosylated hemoglobin', 'glycated hemoglobin', 'hba1c', 'hb a1c', 'a1c'] },

  // Iron
  { metric: 'ferritin', label: 'Ferritin', panel: 'iron', aliases: ['serum ferritin', 'ferritin'] },
  { metric: 'serum_iron', label: 'Serum iron', panel: 'iron', aliases: ['serum iron'] },
  { metric: 'tibc', label: 'TIBC', panel: 'iron', aliases: ['total iron binding capacity', 'tibc'] },
  { metric: 'transferrin_saturation', label: 'Transferrin saturation', panel: 'iron', aliases: ['transferrin saturation', 'iron saturation', '% saturation'] },

  // Kidney
  { metric: 'urea', label: 'Urea', panel: 'kidney', aliases: ['blood urea nitrogen', 'blood urea', 'urea nitrogen', 'urea', 'bun'] },
  // Parse ratio / urine forms before bare "creatinine" so labels are not clubbed.
  { metric: 'pcr', label: 'Protein/Creatinine ratio', panel: 'kidney', aliases: ['urinary protein creatinine ratio', 'protein/creatinine ratio', 'protein creatinine ratio', 'protein/creatinine', 'pcr'] },
  { metric: 'urine_protein', label: 'Urine protein', panel: 'kidney', aliases: ['protein, urine', 'urine protein', 'protein urine'] },
  { metric: 'urine_creatinine', label: 'Urine creatinine', panel: 'kidney', aliases: ['creatinine, urine', 'urine creatinine', 'creatinine urine'] },
  { metric: 'creatinine', label: 'Serum creatinine', panel: 'kidney', aliases: ['serum creatinine', 'creatinine'] },
  { metric: 'egfr', label: 'eGFR', panel: 'kidney', aliases: ['estimated gfr', 'egfr', 'gfr'] },
  { metric: 'uric_acid', label: 'Uric acid', panel: 'kidney', aliases: ['serum uric acid', 'uric acid'] },
  { metric: 'sodium', label: 'Sodium', panel: 'kidney', aliases: ['serum sodium', 'sodium'] },
  { metric: 'potassium', label: 'Potassium', panel: 'kidney', aliases: ['serum potassium', 'potassium'] },
  { metric: 'calcium', label: 'Calcium', panel: 'kidney', aliases: ['serum calcium', 'calcium'] },

  // Liver
  { metric: 'alt', label: 'ALT (SGPT)', panel: 'liver', aliases: ['alanine aminotransferase', 'sgpt', 'alt'] },
  { metric: 'ast', label: 'AST (SGOT)', panel: 'liver', aliases: ['aspartate aminotransferase', 'sgot', 'ast'] },
  { metric: 'alp', label: 'Alkaline phosphatase', panel: 'liver', aliases: ['alkaline phosphatase', 'alp'] },
  { metric: 'ggt', label: 'GGT', panel: 'liver', aliases: ['gamma gt', 'ggt', 'ggtp'] },
  { metric: 'bilirubin_total', label: 'Total bilirubin', panel: 'liver', aliases: ['total bilirubin', 'bilirubin total', 'bilirubin'] },
  { metric: 'bilirubin_direct', label: 'Direct bilirubin', panel: 'liver', aliases: ['direct bilirubin', 'conjugated bilirubin'] },
  { metric: 'albumin', label: 'Albumin', panel: 'liver', aliases: ['serum albumin', 'albumin'] },
  { metric: 'total_protein', label: 'Total protein', panel: 'liver', aliases: ['total protein', 'serum protein'] },

  // Cholesterol
  { metric: 'total_cholesterol', label: 'Total cholesterol', panel: 'cholesterol', aliases: ['total cholesterol', 'cholesterol total'] },
  { metric: 'triglycerides', label: 'Triglycerides', panel: 'cholesterol', aliases: ['serum triglycerides', 'triglycerides'] },
  { metric: 'hdl', label: 'HDL cholesterol', panel: 'cholesterol', aliases: ['hdl cholesterol', 'hdl-c', 'hdl'] },
  { metric: 'ldl', label: 'LDL cholesterol', panel: 'cholesterol', aliases: ['ldl cholesterol', 'ldl-c', 'ldl'] },
  { metric: 'vldl', label: 'VLDL cholesterol', panel: 'cholesterol', aliases: ['vldl cholesterol', 'vldl'] },
  { metric: 'non_hdl', label: 'Non-HDL cholesterol', panel: 'cholesterol', aliases: ['non hdl cholesterol', 'non-hdl cholesterol', 'non-hdl', 'non hdl'] },

  // Thyroid
  { metric: 'tsh', label: 'TSH', panel: 'thyroid', aliases: ['thyroid stimulating hormone', 'serum tsh', 'tsh'] },
  { metric: 't3', label: 'T3', panel: 'thyroid', aliases: ['triiodothyronine', 'total t3', 't3'] },
  { metric: 't4', label: 'T4', panel: 'thyroid', aliases: ['thyroxine', 'total t4', 't4'] },
  { metric: 'ft3', label: 'Free T3', panel: 'thyroid', aliases: ['free t3', 'ft3'] },
  { metric: 'ft4', label: 'Free T4', panel: 'thyroid', aliases: ['free t4', 'ft4'] },

  // Vitamins / inflammation
  { metric: 'vitamin_d', label: 'Vitamin D', panel: 'vitamins', aliases: ['25 oh vitamin d', '25-hydroxy vitamin d', 'vitamin d3', 'vitamin d'] },
  { metric: 'vitamin_b12', label: 'Vitamin B12', panel: 'vitamins', aliases: ['vitamin b12', 'vit b12', 'b12'] },
  { metric: 'folate', label: 'Folate', panel: 'vitamins', aliases: ['folic acid', 'folate'] },
  { metric: 'crp', label: 'CRP', panel: 'vitamins', aliases: ['c reactive protein', 'c-reactive protein', 'crp'] },
];

const numberPattern = '(-?\\d+(?:[,.]\\d+)?)';
const rangePattern = new RegExp(`${numberPattern}\\s*(?:-|–|—|to)\\s*${numberPattern}`, 'i');

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normaliseUnit(unit: string | null): string | null {
  if (!unit) return null;
  return unit
    .toLowerCase()
    .replace(/[\s.]/g, '')
    .replace('μ', 'u')
    .replace('µ', 'u')
    .replace('mg\/mgcreat', 'mg/mg')
    .replace('mgmgcreat', 'mg/mg');
}

/** Null/missing OCR units are treated as compatible with a known unit. */
function unitsCompatible(a: string | null, b: string | null): boolean {
  const na = normaliseUnit(a);
  const nb = normaliseUnit(b);
  if (!na || !nb) return true;
  return na === nb;
}

function pickTrendEndpoints<T extends { date: Date; unit: string | null; value: number }>(
  results: T[],
): { oldest: T; newest: T } | null {
  if (results.length < 2) return null;

  const unitCounts = new Map<string, number>();
  for (const result of results) {
    const key = normaliseUnit(result.unit);
    if (!key) continue;
    unitCounts.set(key, (unitCounts.get(key) || 0) + 1);
  }
  const dominantUnit = [...unitCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || null;
  const comparable = dominantUnit
    ? results.filter((result) => unitsCompatible(result.unit, dominantUnit))
    : results;
  if (comparable.length < 2) return null;
  return { oldest: comparable[0], newest: comparable[comparable.length - 1] };
}

export function valueStatus(value: number, low: number | null, high: number | null): RangeStatus {
  if (low === null && high === null) return 'unknown';
  if (low !== null && value < low) return 'low';
  if (high !== null && value > high) return 'high';
  if (low !== null || high !== null) return 'normal';
  return 'unknown';
}

export const LAB_METRIC_OPTIONS: LabMetricOption[] = METRICS.map((item) => ({
  metric: item.metric,
  label: item.label,
  panel: item.panel,
}));

const PANEL_SET = new Set<string>(Object.keys(PANEL_LABELS));

function asNumberOrNull(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  const n = typeof value === 'number' ? value : Number(String(value).replace(',', '.'));
  return Number.isFinite(n) ? n : null;
}

/** Accepts stored JSON / editor payloads and returns validated LabResult rows. */
export function sanitizeLabResults(raw: unknown): LabResult[] {
  if (!Array.isArray(raw)) return [];
  const byMetric = new Map<string, LabResult>();
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const row = item as Record<string, unknown>;
    const metric = String(row.metric || '').trim();
    const value = asNumberOrNull(row.value);
    if (!metric || value === null) continue;
    const option = LAB_METRIC_OPTIONS.find((entry) => entry.metric === metric);
    const panelRaw = String(row.panel || option?.panel || 'other');
    const panel = (PANEL_SET.has(panelRaw) ? panelRaw : 'other') as LabPanel;
    const label = String(row.label || option?.label || metric).trim() || metric;
    const unitRaw = row.unit === null || row.unit === undefined || row.unit === '' ? null : String(row.unit).trim();
    const referenceLow = asNumberOrNull(row.referenceLow);
    const referenceHigh = asNumberOrNull(row.referenceHigh);
    const statusRaw = String(row.status || '');
    const status: RangeStatus = ['low', 'normal', 'high', 'unknown'].includes(statusRaw)
      ? (statusRaw as RangeStatus)
      : valueStatus(value, referenceLow, referenceHigh);
    byMetric.set(metric, {
      metric,
      label,
      panel,
      value,
      unit: unitRaw,
      referenceLow,
      referenceHigh,
      status,
    });
  }
  return [...byMetric.values()];
}

export function resolveReportResults(input: BloodReportInput): LabResult[] {
  if (input.useManualResults) return sanitizeLabResults(input.manualResults || []);
  return parseBloodResults(input.ocrText);
}

/** True when health_record.data marks lab values as manually curated. */
export function hasManualLabOverride(data: unknown): boolean {
  if (!data || typeof data !== 'object') return false;
  return (data as Record<string, unknown>).labResultsManual === true;
}

export function readManualLabResults(data: unknown): LabResult[] {
  if (!data || typeof data !== 'object') return [];
  return sanitizeLabResults((data as Record<string, unknown>).labResults);
}

/**
 * Extracts recognised lab values from OCR text.
 * Searches the whole document per metric so multi-test lines still work.
 */
export function parseBloodResults(ocrText = ''): LabResult[] {
  const results = new Map<string, LabResult>();
  const text = ocrText.replace(/\r/g, '\n').replace(/[ \t]+/g, ' ');
  if (!text.trim()) return [];

  for (const definition of METRICS) {
    const aliases = [...definition.aliases].sort((a, b) => b.length - a.length);
    for (const alias of aliases) {
      const aliasRegex = new RegExp(`(^|[^a-z0-9])${escapeRegex(alias)}([^a-z0-9]|$)`, 'ig');
      let aliasMatch: RegExpExecArray | null;
      let matchedAt: number | null = null;
      while ((aliasMatch = aliasRegex.exec(text)) !== null) {
        // Use a tight local window so neighbouring lines do not leak (e.g. "RATIO" above serum creatinine).
        const labelStart = aliasMatch.index + (aliasMatch[1] ? aliasMatch[1].length : 0);
        const labelEnd = labelStart + alias.length;
        const around = text.slice(Math.max(0, labelStart - 18), labelEnd + 18).toLowerCase();
        const matchedLabel = text.slice(labelStart, labelEnd).toLowerCase();

        // Keep serum creatinine, urine creatinine, and protein/creatinine ratio distinct.
        if (definition.metric === 'creatinine') {
          if (/urine/.test(around)) continue;
          if (/protein\s*\/|\/\s*creatinine|protein\s*creatinine|creatinine\s*ratio|\bpcr\b/.test(around)) {
            continue;
          }
        }
        if (definition.metric === 'urine_creatinine') {
          if (!/urine/.test(around) && !/urine/.test(matchedLabel)) continue;
          if (/protein\s*\/|protein\s*creatinine|creatinine\s*ratio|\bpcr\b/.test(matchedLabel + around.slice(0, 12))) {
            continue;
          }
        }
        if (definition.metric === 'pcr') {
          if (!/(protein|ratio|pcr)/.test(matchedLabel) && !/(protein\s*\/|ratio|\bpcr\b)/.test(around)) {
            continue;
          }
        }
        if (definition.metric === 'urine_protein') {
          if (!/urine|protein\s*,/.test(around) && !/urine/.test(matchedLabel)) continue;
          if (/creatinine/.test(matchedLabel) || /protein\s*\/\s*creatinine|creatinine\s*ratio/.test(around)) {
            continue;
          }
        }
        if (definition.metric === 'total_cholesterol' && /(hdl|ldl|vldl|non)/.test(around)) continue;
        if ((definition.metric === 'hdl' || definition.metric === 'ldl') && /non[\s-]*hdl|non[\s-]*ldl/.test(around)) {
          continue;
        }
        matchedAt = labelStart;
        break;
      }
      if (matchedAt === null) continue;

      const start = matchedAt + alias.length;
      // Limit to the remainder of this line so the next analyte is not pulled into the window.
      const lineEnd = text.indexOf('\n', start);
      const rawWindow = text.slice(start, lineEnd === -1 ? start + 160 : lineEnd);
      const window = rawWindow.replace(/^\s*(?:\([^)]{1,24}\)|\[[^\]]{1,24}\])?\s*[:=\-–—]?\s*/i, '');
      const valueMatch = window.match(new RegExp(`^${numberPattern}`))
        || window.match(new RegExp(`(?:^|\\s)${numberPattern}`));
      if (!valueMatch) continue;
      const valueToken = valueMatch[1] || valueMatch[0];

      const value = Number(String(valueToken).replace(',', '.'));
      if (!Number.isFinite(value)) continue;

      const valueIndex = window.search(new RegExp(escapeRegex(String(valueToken))));
      const afterValue = window.slice(valueIndex + String(valueToken).length).trim();
      // Support "< 0.2 mg/mg" style ceilings and "0.7 - 1.3 mg/dL" ranges on the same line.
      const ceilingMatch = afterValue.match(new RegExp(`(?:<|>|<=|>=)\\s*${numberPattern}`, 'i'));
      const rangeMatch = afterValue.match(rangePattern);
      let referenceLow: number | null = rangeMatch ? Number(rangeMatch[1].replace(',', '.')) : null;
      let referenceHigh: number | null = rangeMatch ? Number(rangeMatch[2].replace(',', '.')) : null;
      if (!rangeMatch && ceilingMatch) {
        const bound = Number(ceilingMatch[1].replace(',', '.'));
        if (Number.isFinite(bound)) {
          if (/</.test(ceilingMatch[0])) referenceHigh = bound;
          else referenceLow = bound;
        }
      }

      // Prefer real units; skip status words (High/Low) and single-letter flags.
      const unitMatch = afterValue.match(
        /(?:^|\s)((?:mg\/(?:dL|dl|L|l|mg(?:\s*creat)?)|g\/(?:dL|dl|L|l)|mmol\/L|umol\/L|µmol\/L|μmol\/L|ng\/(?:mL|ml|dL|dl)|pg\/(?:mL|ml)|ug\/(?:mL|ml|dL|dl)|IU\/L|U\/L|mIU\/L|%|fL|fl|pg|mm\/hr|mm))(?=\s|$)/i,
      )
        || afterValue.match(/(?:^|\s)([a-zA-Zμµ][a-zA-Z0-9μµ/%^.-]{1,18})(?=\s|$)/);
      let unit = unitMatch?.[1] || null;
      if (unit && /^(high|low|normal|h|l|final|method)$/i.test(unit)) unit = null;

      results.set(definition.metric, {
        metric: definition.metric,
        label: definition.label,
        panel: definition.panel,
        value,
        unit,
        referenceLow: Number.isFinite(referenceLow as number) ? referenceLow : null,
        referenceHigh: Number.isFinite(referenceHigh as number) ? referenceHigh : null,
        status: valueStatus(value, referenceLow, referenceHigh),
      });
      break;
    }
  }

  return [...results.values()];
}

export function buildBloodReportSummary(inputs: BloodReportInput[]) {
  const reports: BloodReport[] = inputs
    .map((input) => ({
      ...input,
      useManualResults: !!input.useManualResults,
      results: resolveReportResults(input),
    }))
    .filter((report) => report.results.length > 0)
    .sort((a, b) => b.date.getTime() - a.date.getTime());

  const metrics = new Map<string, MetricComparison>();
  for (const report of reports) {
    for (const result of report.results) {
      const existing = metrics.get(result.metric) || {
        metric: result.metric,
        label: result.label,
        panel: result.panel,
        unit: result.unit,
        results: [],
        change: null,
        changePercent: null,
        direction: 'not-comparable' as const,
      };
      existing.results.push({
        ...result,
        reportId: report.id,
        date: report.date,
        source: report.source,
        documentPath: report.documentPath,
      });
      if (!existing.unit && result.unit) existing.unit = result.unit;
      metrics.set(result.metric, existing);
    }
  }

  const comparisons = [...metrics.values()].map((comparison) => {
    comparison.results.sort((a, b) => a.date.getTime() - b.date.getTime());
    const endpoints = pickTrendEndpoints(comparison.results);
    if (endpoints) {
      const { oldest, newest } = endpoints;
      const change = newest.value - oldest.value;
      comparison.change = change;
      comparison.changePercent = oldest.value === 0 ? null : (change / Math.abs(oldest.value)) * 100;
      comparison.direction = Math.abs(change) < 0.000001 ? 'unchanged' : change > 0 ? 'increased' : 'decreased';
      comparison.unit = newest.unit || oldest.unit || comparison.unit;
    }
    return comparison;
  }).sort((a, b) => a.label.localeCompare(b.label));

  const panels: PanelSummary[] = PANEL_ORDER
    .map((panel) => ({
      panel,
      label: PANEL_LABELS[panel],
      comparisons: comparisons.filter((item) => item.panel === panel),
    }))
    .filter((panel) => panel.comparisons.length > 0);

  const keyFindings: KeyFinding[] = [];
  for (const comparison of comparisons) {
    const latest = comparison.results[comparison.results.length - 1];
    const unit = latest.unit ? ` ${latest.unit}` : '';
    if (latest.status === 'high' || latest.status === 'low') {
      const boundary = latest.status === 'high'
        ? (latest.referenceHigh !== null ? `above ${latest.referenceHigh}` : 'above the lab reference')
        : (latest.referenceLow !== null ? `below ${latest.referenceLow}` : 'below the lab reference');
      keyFindings.push({
        severity: 'attention',
        text: `${comparison.label} was ${latest.value}${unit} on ${formatDate(latest.date)}, ${boundary}${unit} on that lab's stated range.`,
      });
    }
    if (
      comparison.direction !== 'not-comparable'
      && comparison.direction !== 'unchanged'
      && comparison.changePercent !== null
      && Math.abs(comparison.changePercent) >= 5
    ) {
      keyFindings.push({
        severity: 'change',
        text: `${comparison.label} ${comparison.direction} from ${comparison.results[0].value}${unit} on ${formatDate(comparison.results[0].date)} to ${latest.value}${unit} on ${formatDate(latest.date)}.`,
      });
    }
  }

  if (keyFindings.length === 0 && reports.length > 0) {
    keyFindings.push({
      severity: 'information',
      text: 'No values outside a stated laboratory range or material changes were detected in the extracted results.',
    });
  }

  return { reports, comparisons, panels, keyFindings };
}

export function formatDate(date: Date): string {
  return new Intl.DateTimeFormat('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }).format(date);
}

export { PANEL_LABELS, PANEL_ORDER };
