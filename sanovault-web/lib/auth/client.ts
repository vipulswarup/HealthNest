'use client';

import { createAuthClient } from '@neondatabase/auth/next';

export const authClient = createAuthClient();

export function useSession() {
  const { data, isPending } = authClient.useSession();
  const fullName = data?.user.name?.trim() || data?.user.email || 'User';

  return {
    data: data ? { user: {
      id: data.user.id,
      email: data.user.email,
      name: fullName,
      firstName: fullName.split(/\s+/)[0] || 'User',
    } } : null,
    status: isPending ? 'loading' : data ? 'authenticated' : 'unauthenticated',
  } as const;
}

export async function signOut({ callbackUrl }: { callbackUrl?: string } = {}) {
  const result = await authClient.signOut();
  if (callbackUrl) window.location.assign(callbackUrl);
  return result;
}
