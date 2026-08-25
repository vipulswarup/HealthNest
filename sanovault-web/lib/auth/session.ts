import { headers } from 'next/headers';
import { auth } from '@/lib/auth/server';
import { getUserFromMobileToken, parseBearerToken } from '@/lib/auth/mobile-session';
import { sql } from '@/lib/db/neon';
import { BETA_ACKNOWLEDGEMENT_VERSION } from '@/lib/legal/beta-acknowledgement';

export type CurrentUser = { id: string; email: string; name: string };

function splitName(name: string) {
  const [firstName, ...rest] = name.trim().split(/\s+/);
  return { firstName: firstName || 'User', lastName: rest.length ? rest.join(' ') : null };
}

/**
 * Returns an authenticated user and ensures there is a local profile. This is
 * intentionally not the default for health-data routes: use getCurrentUser()
 * there so beta acknowledgement remains mandatory before data access.
 */
export async function getAuthenticatedUser(): Promise<CurrentUser | null> {
  const headerList = await headers();
  const bearer = parseBearerToken(headerList.get('authorization'));
  if (bearer) {
    return getUserFromMobileToken(bearer);
  }

  const { data: session } = await auth.getSession();
  const user = session?.user;
  if (!user) return null;

  const email = user.email?.trim().toLowerCase() || '';
  const name = user.name?.trim() || email || 'User';
  const { firstName, lastName } = splitName(name);
  await sql`
    INSERT INTO profiles (user_id, first_name, last_name, email)
    VALUES (${user.id}, ${firstName}, ${lastName}, ${email || null})
    ON CONFLICT (user_id) DO UPDATE SET
      email = COALESCE(EXCLUDED.email, profiles.email),
      updated_at = NOW()
  `;
  return { id: user.id, email, name };
}

/**
 * Returns a user only after the current beta acknowledgement has been stored.
 * Keeping this enforcement alongside the shared session helper means every
 * API route that uses it fails closed if an account bypasses the sign-up UI.
 */
export async function getCurrentUser(): Promise<CurrentUser | null> {
  const user = await getAuthenticatedUser();
  if (!user) return null;

  const [acknowledgement] = await sql`
    SELECT 1
    FROM beta_acknowledgements
    WHERE user_id = ${user.id}
      AND acknowledgement_version = ${BETA_ACKNOWLEDGEMENT_VERSION}
    LIMIT 1
  `;

  return acknowledgement ? user : null;
}

export async function requireCurrentUser(): Promise<CurrentUser> {
  const user = await getCurrentUser();
  if (!user) throw new Error('UNAUTHORIZED');
  return user;
}
