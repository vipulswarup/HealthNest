import { sql } from '@/lib/db/neon';
import { dobPasswordCandidates } from '@/lib/pdf/passwords';
import { loadPdf, PdfPasswordError, tryUnlockPdf } from '@/lib/pdf/ops';
import { addPatientFilePassword, listPatientFilePasswords } from '@/lib/services/file-password.service';

export type PdfUnlockResult = {
  bytes: Uint8Array;
  locked: boolean;
  passwordSaved: boolean;
};

function uniquePasswords(values: Array<string | null | undefined>): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    const trimmed = value?.trim();
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    out.push(trimmed);
  }
  return out;
}

async function patientDob(patientId: string): Promise<string | null> {
  const [row] = await sql`
    SELECT date_of_birth FROM patients WHERE id = ${patientId}::uuid LIMIT 1
  `;
  if (!row?.date_of_birth) return null;
  if (row.date_of_birth instanceof Date) return row.date_of_birth.toISOString().slice(0, 10);
  return String(row.date_of_birth).slice(0, 10);
}

export async function isPdfLocked(bytes: Uint8Array): Promise<boolean> {
  try {
    await loadPdf(bytes);
    return false;
  } catch (error) {
    if (error instanceof PdfPasswordError) return true;
    throw error;
  }
}

/**
 * Try saved person passwords, DOB variants, then any extra passwords from this request.
 * A newly working extra password is stored on the person.
 */
export async function unlockPdfForPatient(options: {
  bytes: Uint8Array;
  patientId: string;
  extraPasswords?: string[];
  saveExtraPasswords?: boolean;
  actorUserId?: string;
}): Promise<PdfUnlockResult> {
  const { bytes, patientId } = options;
  if (!(await isPdfLocked(bytes))) {
    return { bytes, locked: false, passwordSaved: false };
  }

  const saved = await listPatientFilePasswords(patientId);
  const dob = dobPasswordCandidates(await patientDob(patientId));
  const extras = (options.extraPasswords || []).map((value) => value.trim()).filter(Boolean);
  const candidates = uniquePasswords([...saved.map((row) => row.password), ...dob, ...extras]);

  try {
    const unlocked = await tryUnlockPdf(bytes, candidates);
    let passwordSaved = false;
    if (options.saveExtraPasswords && options.actorUserId) {
      const savedSet = new Set(saved.map((row) => row.password));
      for (const extra of extras) {
        if (savedSet.has(extra)) continue;
        try {
          await tryUnlockPdf(bytes, [extra]);
          await addPatientFilePassword({
            patientId,
            userId: options.actorUserId,
            password: extra,
          });
          passwordSaved = true;
          break;
        } catch (error) {
          if (!(error instanceof PdfPasswordError)) throw error;
        }
      }
    }
    return { bytes: unlocked, locked: false, passwordSaved };
  } catch (error) {
    if (error instanceof PdfPasswordError) {
      return { bytes, locked: true, passwordSaved: false };
    }
    throw error;
  }
}
