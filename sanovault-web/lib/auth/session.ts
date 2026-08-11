import { auth } from '@/lib/auth/server';
import { sql } from '@/lib/db/neon';

export type CurrentUser = { id: string; email: string; name: string };

function splitName(name: string) {
  const [firstName, ...rest] = name.trim().split(/\s+/);
  return { firstName: firstName || 'User', lastName: rest.length ? rest.join(' ') : null };
}

export async function getCurrentUser(): Promise<CurrentUser | null> {
  const { data: session } = await auth.getSession();
  const user = session?.user;
  if (!user) return null;

  const name = user.name?.trim() || user.email;
  const { firstName, lastName } = splitName(name);
  await sql`
    INSERT INTO profiles (user_id, first_name, last_name)
    VALUES (${user.id}, ${firstName}, ${lastName})
    ON CONFLICT (user_id) DO NOTHING
  `;
  return { id: user.id, email: user.email, name };
}

export async function requireCurrentUser(): Promise<CurrentUser> {
  const user = await getCurrentUser();
  if (!user) throw new Error('UNAUTHORIZED');
  return user;
}
