import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { dissolveHouseholdIfEmpty } from '@/lib/households/access';
import { getHouseholdForMember } from '@/lib/households/helpers';
import { AppError, handleError } from '@/lib/middleware/error-handler';

const idSchema = z.string().uuid();

export async function DELETE(
  _: NextRequest,
  { params }: { params: Promise<{ id: string; userId: string }> }
) {
  try {
    const user = await getCurrentUser();
    if (!user) throw new AppError('Unauthorized', 401);

    const { id, userId: targetUserId } = await params;
    const parsedId = idSchema.safeParse(id);
    if (!parsedId.success) throw new AppError('Invalid household ID', 400);
    if (!targetUserId) throw new AppError('Invalid user ID', 400);

    if (targetUserId === user.id) {
      throw new AppError('Use leave to remove yourself from the household', 400);
    }

    const household = await getHouseholdForMember(parsedId.data, user.id);
    if (!household) throw new AppError('Household not found', 404);

    const [removed] = await sql`
      DELETE FROM household_members
      WHERE household_id = ${parsedId.data}::uuid AND user_id = ${targetUserId}
      RETURNING user_id
    `;
    if (!removed) throw new AppError('Member not found', 404);

    await dissolveHouseholdIfEmpty(parsedId.data, user.id);
    return NextResponse.json({ message: 'Member removed' });
  } catch (error) {
    return handleError(error);
  }
}
