import { sql } from '../db/neon';
import { HealthRecordCategory } from '../types/health-record-category.types';

let categoriesCache: HealthRecordCategory[] | null = null;
let cacheTimestamp = 0;
const CACHE_TTL = 5 * 60 * 1000;

const CLASSIFICATION_ALIASES: Record<string, string> = {
  'pathology test': 'Lab Report',
  'lab test': 'Lab Report',
  'laboratory': 'Lab Report',
  'diagnostic report': 'Lab Report',
  'diagnostics report': 'Lab Report',
  'blood test': 'Lab Report',
  'haematology': 'Lab Report',
  'hematology': 'Lab Report',
  'radiology scan': 'Imaging Report',
  'radiology': 'Imaging Report',
  'imaging': 'Imaging Report',
  'x-ray': 'Imaging Report',
  'mri': 'Imaging Report',
  'ct scan': 'Imaging Report',
  'medication order': 'Prescription',
  'medication': 'Prescription',
  'clinical synopsis': 'Consultation Note',
  'diagnosis': 'Consultation Note',
  'consultation': 'Consultation Note',
  'consult': 'Consultation Note',
  'discharge summary': 'Discharge Summary',
  'discharge': 'Discharge Summary',
  'normal discharge': 'Discharge Summary',
};

export async function getAllCategories(): Promise<HealthRecordCategory[]> {
  const now = Date.now();
  if (categoriesCache && now - cacheTimestamp < CACHE_TTL) {
    return categoriesCache;
  }

  const rows = await sql`
    SELECT id, code, display_name AS "displayName", description, is_active AS "isActive"
    FROM health_record_categories
    WHERE is_active = TRUE
    ORDER BY display_name
  `;

  categoriesCache = rows.map((row) => ({
    id: String(row.id),
    code: String(row.code),
    displayName: String(row.displayName),
    standardSystem: null,
    standardCode: null,
    isActive: Boolean(row.isActive),
    createdAt: new Date(),
    updatedAt: new Date(),
  }));
  cacheTimestamp = now;
  return categoriesCache ?? [];
}

export async function getCategoryByCode(code: string): Promise<HealthRecordCategory | null> {
  const categories = await getAllCategories();
  return categories.find((cat) => cat.code === code) || null;
}

export function getCategoryDisplayName(code: string, categories: HealthRecordCategory[]): string {
  return categories.find((cat) => cat.code === code)?.displayName || code;
}

export function getValidCategoryDisplayNames(categories: HealthRecordCategory[]): string[] {
  return categories.map((cat) => cat.displayName);
}

/** Map free-form AI classification onto an exact dropdown label. */
export function resolveClassification(
  raw: string | null | undefined,
  validNames: string[],
): string {
  if (!validNames.length) return raw?.trim() || 'Other';
  if (!raw?.trim()) {
    return validNames.find((name) => name === 'Other') || validNames[0];
  }

  const normalized = raw.trim().toLowerCase();
  const exact = validNames.find((name) => name.toLowerCase() === normalized);
  if (exact) return exact;

  const aliasTarget = CLASSIFICATION_ALIASES[normalized];
  if (aliasTarget) {
    const aliased = validNames.find((name) => name === aliasTarget);
    if (aliased) return aliased;
  }

  const contains = validNames.find(
    (name) =>
      normalized.includes(name.toLowerCase()) ||
      name.toLowerCase().includes(normalized),
  );
  if (contains) return contains;

  return validNames.find((name) => name === 'Other') || validNames[0];
}
