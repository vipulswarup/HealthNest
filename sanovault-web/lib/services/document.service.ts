import { sql } from '@/lib/db/neon';
import { CreateDocumentInput, DocumentMetadata } from '@/lib/types/document.types';

type DocumentRow = Record<string, any>;

function toDocument(row: DocumentRow): DocumentMetadata {
  return {
    id: row.id,
    _id: row.id,
    userId: row.owner_id,
    fileName: row.file_name,
    fileSize: Number(row.file_size),
    fileType: row.file_type,
    r2Key: row.r2_key,
    uploadedAt: row.uploaded_at,
    status: row.status,
    ocrStatus: row.ocr_status || undefined,
    ocrText: row.ocr_text || undefined,
    aiStatus: row.ai_status || undefined,
    classification: row.classification || undefined,
    extractedData: row.extracted_data || undefined,
    suggestedTags: row.suggested_tags || [],
    confidenceScore: row.confidence_score === null ? undefined : Number(row.confidence_score),
    isApproved: row.is_approved,
    approvedAt: row.approved_at || undefined,
    approvedTags: row.approved_tags || [],
    rejectionReason: row.rejection_reason || undefined,
  };
}

export async function createDocument(input: CreateDocumentInput): Promise<DocumentMetadata> {
  const [row] = await sql`
    INSERT INTO documents (owner_id, file_name, file_size, file_type, r2_key, storage_provider)
    VALUES (${input.userId}, ${input.fileName}, ${input.fileSize}, ${input.fileType}, ${input.r2Key}, 'r2')
    RETURNING *
  `;
  return toDocument(row);
}

export async function getDocumentById(id: string): Promise<DocumentMetadata | null> {
  const [row] = await sql`SELECT * FROM documents WHERE id = ${id}::uuid`;
  return row ? toDocument(row) : null;
}

export async function listUserDocuments(userId: string): Promise<DocumentMetadata[]> {
  const rows = await sql`SELECT * FROM documents WHERE owner_id = ${userId} ORDER BY uploaded_at DESC`;
  return rows.map(toDocument);
}

export async function updateDocumentStatus(
  id: string,
  updates: Partial<DocumentMetadata>
): Promise<void> {
  await sql`
    UPDATE documents SET
      status = COALESCE(${updates.status ?? null}, status),
      ocr_status = COALESCE(${updates.ocrStatus ?? null}, ocr_status),
      ocr_text = COALESCE(${updates.ocrText ?? null}, ocr_text),
      ai_status = COALESCE(${updates.aiStatus ?? null}, ai_status),
      classification = COALESCE(${updates.classification ?? null}, classification),
      extracted_data = COALESCE(${updates.extractedData === undefined ? null : JSON.stringify(updates.extractedData)}::jsonb, extracted_data),
      suggested_tags = COALESCE(${updates.suggestedTags ?? null}, suggested_tags),
      confidence_score = COALESCE(${updates.confidenceScore ?? null}, confidence_score),
      is_approved = COALESCE(${updates.isApproved ?? null}, is_approved),
      approved_at = COALESCE(${updates.approvedAt ?? null}, approved_at),
      approved_tags = COALESCE(${updates.approvedTags ?? null}, approved_tags),
      rejection_reason = COALESCE(${updates.rejectionReason ?? null}, rejection_reason),
      updated_at = NOW()
    WHERE id = ${id}::uuid
  `;
}

export async function deleteDocument(id: string): Promise<void> {
  await sql`DELETE FROM documents WHERE id = ${id}::uuid`;
}
