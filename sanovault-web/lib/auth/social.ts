import { authClient } from '@/lib/auth/client';

export type NeonSocialProvider = 'google';

export async function signInWithGoogle(callbackURL = '/dashboard') {
  return authClient.signIn.social({
    provider: 'google',
    callbackURL,
    newUserCallbackURL: callbackURL,
    errorCallbackURL: '/auth/signin?error=oauth_google',
  });
}
