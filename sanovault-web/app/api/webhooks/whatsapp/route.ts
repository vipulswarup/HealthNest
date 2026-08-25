import { randomUUID } from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@/lib/db/neon';
import { uploadToR2 } from '@/lib/r2';
import { createDocument } from '@/lib/services/document.service';
import { verifyUploadSignature } from '@/lib/security/file-signature';
import { recordAuditEvent } from '@/lib/services/audit.service';
import { notifyPatientHousehold } from '@/lib/services/device-push.service';

function configured() {
  return Boolean(
    process.env.WHATSAPP_VERIFY_TOKEN
    && process.env.WHATSAPP_ACCESS_TOKEN
    && process.env.WHATSAPP_PHONE_NUMBER_ID,
  );
}

export async function GET(request: NextRequest) {
  const mode = request.nextUrl.searchParams.get('hub.mode');
  const token = request.nextUrl.searchParams.get('hub.verify_token');
  const challenge = request.nextUrl.searchParams.get('hub.challenge');
  if (mode === 'subscribe' && token && token === process.env.WHATSAPP_VERIFY_TOKEN && challenge) {
    return new NextResponse(challenge, { status: 200 });
  }
  return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
}

type WhatsAppMessage = {
  from?: string;
  type?: string;
  image?: { id?: string; mime_type?: string };
  document?: { id?: string; filename?: string; mime_type?: string };
  button?: { text?: string; payload?: string };
  interactive?: { button_reply?: { id?: string; title?: string } };
};

async function graphGet(path: string) {
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  const response = await fetch(`https://graph.facebook.com/v21.0/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error('WhatsApp media lookup failed');
  return response.json() as Promise<{ url?: string }>;
}

async function downloadMedia(url: string) {
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!response.ok) throw new Error('WhatsApp media download failed');
  return Buffer.from(await response.arrayBuffer());
}

async function reply(to: string, text: string) {
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID;
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  await fetch(`https://graph.facebook.com/v21.0/${phoneId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to,
      type: 'text',
      text: { body: text },
    }),
  }).catch(() => undefined);
}

export async function POST(request: NextRequest) {
  if (!configured()) {
    return NextResponse.json({ ok: false, reason: 'not_configured' }, { status: 503 });
  }

  const payload = await request.json().catch(() => null) as {
    entry?: Array<{ changes?: Array<{ value?: { messages?: WhatsAppMessage[] } }> }>;
  } | null;
  const messages = payload?.entry?.flatMap((entry) => entry.changes || [])
    .flatMap((change) => change.value?.messages || []) || [];

  for (const message of messages) {
    const from = message.from;
    if (!from) continue;
    const [map] = await sql`
      SELECT household_id, default_patient_id
      FROM whatsapp_sender_maps
      WHERE phone = ${from}
      LIMIT 1
    `;
    if (!map?.default_patient_id) {
      await reply(from, 'This WhatsApp number is not linked to a SanoVault family folder yet.');
      continue;
    }

    const media = message.document || message.image;
    if (!media?.id) {
      await reply(from, 'Send a photo or PDF of the report. We will file it for the person already set for this chat.');
      continue;
    }

    try {
      const meta = await graphGet(media.id);
      if (!meta.url) throw new Error('missing url');
      const bytes = await downloadMedia(meta.url);
      const mimeGuess = media.mime_type || 'application/pdf';
      const verified = verifyUploadSignature(bytes, mimeGuess);
      if (!verified) {
        await reply(from, 'That file type cannot be stored. Send a PDF or photo.');
        continue;
      }
      const ownerId = String((await sql`
        SELECT user_id FROM household_members WHERE household_id = ${String(map.household_id)}::uuid LIMIT 1
      `)[0]?.user_id || '');
      if (!ownerId) continue;
      const storageKey = `${ownerId}/${randomUUID()}.${verified.extension}`;
      await uploadToR2(storageKey, bytes, verified.mimeType);
      const document = await createDocument({
        userId: ownerId,
        fileName: ('filename' in media && media.filename) ? String(media.filename) : `whatsapp.${verified.extension}`,
        fileSize: bytes.length,
        fileType: verified.mimeType,
        r2Key: storageKey,
      });
      const documentId = document.id || document._id;
      const [record] = await sql`
        INSERT INTO health_records (patient_id, record_type, data, tags, source, document_id)
        VALUES (
          ${String(map.default_patient_id)}::uuid,
          'OTHER',
          '{}'::jsonb,
          ARRAY['whatsapp'],
          'WhatsApp',
          ${documentId}::uuid
        )
        RETURNING id
      `;
      await recordAuditEvent({
        actorId: ownerId,
        patientId: String(map.default_patient_id),
        eventType: 'created',
        entityType: 'health_record',
        entityId: String(record.id),
        metadata: { via: 'whatsapp' },
      });
      await notifyPatientHousehold(String(map.default_patient_id), {
        title: 'WhatsApp report filed',
        body: 'A file sent on WhatsApp is now in SanoVault.',
        data: { recordId: String(record.id) },
      });
      await reply(from, 'Saved in SanoVault.');
    } catch {
      await reply(from, 'We could not save that file. Try again, or use Share to SanoVault in the app.');
    }
  }

  return NextResponse.json({ ok: true });
}
