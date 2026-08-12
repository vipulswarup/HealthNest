import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { dissolveHouseholdIfEmpty, setActiveHouseholdId } from '@/lib/households/access';
import { getHouseholdForMember } from '@/lib/households/helpers';
import { AppError, handleError } from '@/lib/middleware/error-handler';

const idSchema = z.string().uuid();

export async function POST(_: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const user = await getCurrentUser();
    if (!user) throw new AppError('Unauthorized', 401);

    const parsedId = idSchema.safeParse((await params).id);
    if (!parsedId.success) throw new AppError('Invalid household ID', 400);

    const household = await getHouseholdForMember(parsedId.data, user.id);
    if (!household) throw new AppError('Household not found', 404);

    await sql`
      DELETE FROM household_members
      WHERE household_id = ${parsedId.data}::uuid AND user_id = ${user.id}
    `;

    const dissolved = await dissolveHouseholdIfEmpty(parsedId.data, user.id);

    const [prefs] = await sql`
      SELECT preferences->>'activeHouseholdId' AS active_household_id
      FROM profiles WHERE user_id = ${user.id}
    `;
    if (prefs?.active_household_id === parsedId.data) {
      await setActiveHouseholdId(user.id, null);
    }

    return NextResponse.json({
      message: dissolved ? 'Left and dissolved household' : 'Left household',
      dissolved,
    });
  } catch (error) {
    return handleError(error);
  }
}
