import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { AppError, handleError } from '@/lib/middleware/error-handler';

const sourceSchema = z.object({ name: z.string().trim().min(1) });

async function authorize() { if (!await getCurrentUser()) throw new AppError('Unauthorized', 401); }
export async function GET() {
  try { await authorize(); return NextResponse.json(await sql`SELECT id, preferred_name AS "preferredName", aliases, is_active AS "isActive", created_at AS "createdAt", updated_at AS "updatedAt" FROM healthcare_sources WHERE is_active = TRUE ORDER BY preferred_name`); }
  catch (error) { return handleError(error); }
}

export async function POST(request: NextRequest) {
  try {
    await authorize();
    const parsed = sourceSchema.safeParse(await request.json());
    if (!parsed.success) throw new AppError(parsed.error.issues[0].message, 400, 'VALIDATION_ERROR');
    const [source] = await sql`
      INSERT INTO healthcare_sources (preferred_name) VALUES (${parsed.data.name})
      ON CONFLICT (preferred_name) DO UPDATE SET updated_at = NOW()
      RETURNING id, preferred_name AS "preferredName", aliases, is_active AS "isActive", created_at AS "createdAt", updated_at AS "updatedAt"
    `;
    return NextResponse.json(source, { status: 201 });
  } catch (error) { return handleError(error); }
}
