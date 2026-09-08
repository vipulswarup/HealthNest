import type { KeyFinding } from '@/lib/reports/blood-summary';
import { isoDateFromUnknown } from '@/lib/vitals/growth';

export const DOCTOR_PACKET_HIGHLIGHT_LIMIT = 5;

type MedicationLike = {
  originalBrandName: string;
  dosage: string;
  frequency: string;
  route: string;
  indication: string;
  composition: {
    formulation: string;
    ingredients: Array<{ canonicalInn: string; strength: string; strengthUnit: string }>;
  };
};

export function medicationLine(medication: MedicationLike) {
  const generic = medication.composition.ingredients
    .map((ingredient) => `${ingredient.canonicalInn} ${ingredient.strength} ${ingredient.strengthUnit}`.trim())
    .filter(Boolean)
    .join(' + ');
  const name = generic || medication.originalBrandName;
  const form = medication.composition.formulation ? ` · ${medication.composition.formulation}` : '';
  return `${name}${form} — ${medication.dosage}, ${medication.frequency}, ${medication.route}`;
}

export function medicationSummaryLine(medication: MedicationLike) {
  return `${medication.originalBrandName} — ${medication.frequency}`;
}

export function medicationDetailLine(medication: MedicationLike) {
  return medicationLine(medication);
}

export function conditionLines(medications: MedicationLike[]) {
  const seen = new Set<string>();
  const lines: string[] = [];
  for (const medication of medications) {
    const indication = medication.indication.trim();
    if (!indication) continue;
    const key = indication.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    lines.push(indication);
    if (lines.length >= 6) break;
  }
  return lines;
}

export function pickLabHighlights(findings: KeyFinding[]) {
  const attention = findings.filter((finding) => finding.severity === 'attention');
  const change = findings.filter((finding) => finding.severity === 'change');
  const picked: KeyFinding[] = [];
  const seen = new Set<string>();
  for (const finding of [...attention, ...change]) {
    const key = finding.metric || finding.text;
    if (seen.has(key)) continue;
    seen.add(key);
    picked.push(finding);
    if (picked.length >= DOCTOR_PACKET_HIGHLIGHT_LIMIT) break;
  }
  if (picked.length === 0) {
    const info = findings.find((finding) => finding.severity === 'information');
    if (info) return [info];
  }
  return picked;
}

export type LatestLabCandidate = {
  id: string;
  date: Date;
  source: string;
  resultCount: number;
  ocrChars: number;
  documentPath?: string;
};

export function formatPacketDate(date: Date) {
  return new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }).format(date);
}

export function labPacketLines(options: {
  findings: KeyFinding[];
  latestCandidate: LatestLabCandidate | null;
}) {
  const highlights = pickLabHighlights(options.findings).map((finding) => finding.text);
  const latest = options.latestCandidate;
  if (!latest) return highlights;
  const latestLabel = `${formatPacketDate(latest.date)} · ${latest.source}`;
  if (latest.resultCount === 0) {
    return [
      `Latest lab (${latestLabel}) is attached, but values could not be read yet.`,
      ...highlights.map((line) => `Earlier result: ${line}`),
    ];
  }
  return highlights;
}

export function ageFromDateOfBirth(value: string | Date | null | undefined) {
  const birthIso = isoDateFromUnknown(value);
  const todayIso = isoDateFromUnknown(new Date());
  if (!birthIso || !todayIso) return null;
  const [birthYear, birthMonth, birthDay] = birthIso.split('-').map(Number);
  const [todayYear, todayMonth, todayDay] = todayIso.split('-').map(Number);
  let age = todayYear - birthYear;
  if (todayMonth < birthMonth || (todayMonth === birthMonth && todayDay < birthDay)) age -= 1;
  return age >= 0 && age < 130 ? age : null;
}

export function doctorPacketWhatsAppText(packet: {
  origin: string;
  patientId: string;
  name: string;
  identityLine: string;
  conditions: string[];
  medicines: string[];
  labHighlights: string[];
  bloodPressure: string[];
  growth: string[];
  vaccinations: string[];
  visitNotes: string[];
  documents: Array<{ label: string; href: string }>;
}) {
  const lines = [
    `SanoVault — for the doctor`,
    packet.name,
    packet.identityLine,
    '',
    'Conditions',
    ...(packet.conditions.length ? packet.conditions.map((line) => `- ${line}`) : ['- None recorded']),
    '',
    'Current medicines',
    ...(packet.medicines.length ? packet.medicines.map((line) => `- ${line}`) : ['- None recorded']),
    '',
    'Lab highlights',
    ...(packet.labHighlights.length ? packet.labHighlights.map((line) => `- ${line}`) : ['- No recent lab highlights']),
    '',
    'Blood pressure',
    ...(packet.bloodPressure.length ? packet.bloodPressure.map((line) => `- ${line}`) : ['- Not logged in SanoVault yet']),
    '',
    'Height & weight',
    ...(packet.growth.length ? packet.growth.map((line) => `- ${line}`) : ['- Not logged in SanoVault yet']),
    '',
    'Vaccinations',
    ...(packet.vaccinations.length ? packet.vaccinations.map((line) => `- ${line}`) : ['- None recorded']),
  ];
  if (packet.visitNotes.length) {
    lines.push('', 'Visit notes', ...packet.visitNotes.map((line) => `- ${line}`));
  }
  if (packet.documents.length) {
    lines.push('', 'Reports');
    for (const document of packet.documents) {
      lines.push(`- ${document.label}: ${document.href}`);
    }
  }
  lines.push('', `Open packet: ${packet.origin.replace(/\/$/, '')}/for-the-doctor?patientId=${packet.patientId}`);
  return lines.join('\n');
}
