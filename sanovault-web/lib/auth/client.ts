'use client';

import { createAuthClient } from '@neondatabase/auth/next';

export const authClient = createAuthClient();

export function useSession() {
  const { data, isPending } = authClient.useSession();

  return {
    data: data ? { user: {
      id: data.user.id,
      email: data.user.email,
      name: data.user.name,
      firstName: data.user.name.split(/\s+/)[0] || 'User',
    } } : null,
    status: isPending ? 'loading' : data ? 'authenticated' : 'unauthenticated',
  } as const;
}

export async function signOut({ callbackUrl }: { callbackUrl?: string } = {}) {
  const result = await authClient.signOut();
  if (callbackUrl) window.location.assign(callbackUrl);
  return result;
}
