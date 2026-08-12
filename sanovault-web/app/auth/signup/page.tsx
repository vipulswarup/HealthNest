'use client';

import { authClient } from '@/lib/auth/client';
import SocialAuthButtons from '@/components/auth/SocialAuthButtons';
import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Image from 'next/image';
import { BETA_ACKNOWLEDGEMENT_VERSION } from '@/lib/legal/beta-acknowledgement';

function SignUpContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const callbackUrl = searchParams.get('callbackUrl') || '/dashboard';
  const emailFromInvite = searchParams.get('email')?.trim().toLowerCase() || '';
  const betaAcknowledgementUrl = `/beta-acknowledgement?${new URLSearchParams({ callbackUrl })}`;

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState(emailFromInvite);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [agreedToBetaAcknowledgement, setAgreedToBetaAcknowledgement] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (emailFromInvite) setEmail(emailFromInvite);
  }, [emailFromInvite]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (password.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }

    if (!agreedToBetaAcknowledgement) {
      setError('You must agree to the beta acknowledgement to create an account.');
      return;
    }

    setLoading(true);

    try {
      const result = await authClient.signUp.email({
        name: [firstName, lastName].filter(Boolean).join(' '),
        email: email.trim().toLowerCase(),
        password,
        callbackURL: callbackUrl,
      });

      if (result?.error) {
        setError(result.error.message || 'Unable to create account. Please try again.');
        return;
      }

      const acknowledgement = await fetch('/api/users/beta-acknowledgement', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ version: BETA_ACKNOWLEDGEMENT_VERSION }),
      });
      if (!acknowledgement.ok) {
        router.push(`/beta-acknowledgement?${new URLSearchParams({ callbackUrl })}`);
        return;
      }

      router.push(callbackUrl);
      router.refresh();
    } catch {
      setError('Unable to create account. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const signInHref = (() => {
    const qs = new URLSearchParams({ callbackUrl });
    if (email.trim()) qs.set('email', email.trim().toLowerCase());
    return `/auth/signin?${qs.toString()}`;
  })();

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8 bg-white rounded-2xl shadow-xl p-8">
        <div className="text-center">
          <div className="flex justify-center mb-4">
            <Image
              src="/logo.png"
              alt="SanoVault Logo"
              width={80}
              height={80}
              className="rounded-full"
              priority
            />
          </div>
          <h2 className="text-3xl font-extrabold text-gray-900">
            Create your account
          </h2>
          <p className="mt-2 text-sm text-gray-600">
            {emailFromInvite
              ? 'Finish signing up to accept your household invite'
              : 'Start managing your health records with SanoVault'}
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          {error && (
            <div className="rounded-md bg-red-50 p-4">
              <div className="text-sm text-red-800">{error}</div>
            </div>
          )}
          <div className="space-y-4">
            <div>
              <label htmlFor="firstName" className="block text-sm font-medium text-gray-700">
                First Name
              </label>
              <input
                id="firstName"
                name="firstName"
                type="text"
                required
                className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-[#0175C2] focus:border-[#0175C2] sm:text-sm"
                placeholder="First name"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="lastName" className="block text-sm font-medium text-gray-700">
                Last Name
              </label>
              <input
                id="lastName"
                name="lastName"
                type="text"
                className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-[#0175C2] focus:border-[#0175C2] sm:text-sm"
                placeholder="Last name (optional)"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                Email address
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-[#0175C2] focus:border-[#0175C2] sm:text-sm"
                placeholder="Email address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="new-password"
                required
                minLength={8}
                className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-[#0175C2] focus:border-[#0175C2] sm:text-sm"
                placeholder="Password (min 8 characters)"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700">
                Confirm Password
              </label>
              <input
                id="confirmPassword"
                name="confirmPassword"
                type="password"
                autoComplete="new-password"
                required
                minLength={8}
                className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-[#0175C2] focus:border-[#0175C2] sm:text-sm"
                placeholder="Confirm password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
              />
            </div>
            <label className="flex cursor-pointer gap-3 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-gray-800">
              <input
                type="checkbox"
                checked={agreedToBetaAcknowledgement}
                onChange={(e) => setAgreedToBetaAcknowledgement(e.target.checked)}
                className="mt-0.5 h-4 w-4 rounded border-gray-300 text-[#0175C2] focus:ring-[#0175C2]"
              />
              <span>
                I understand SanoVault is a beta, experimental service and is not currently represented as HIPAA, GDPR, or DPDP compliant. I agree to the beta acknowledgement before creating my account.
              </span>
            </label>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              className="group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-lg text-white bg-[#0175C2] hover:bg-[#015a96] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#0175C2] disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
            >
              {loading ? 'Creating account...' : 'Sign up'}
            </button>
          </div>

          <SocialAuthButtons
            mode="signup"
            callbackURL={betaAcknowledgementUrl}
            disabled={loading || !agreedToBetaAcknowledgement}
            onError={setError}
          />

          <div className="text-center">
            <a
              href={signInHref}
              className="font-medium text-[#0175C2] hover:text-[#015a96] transition-colors"
            >
              Already have an account? Sign in
            </a>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function SignUpPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-white">
          <div className="text-center text-gray-600">Loading...</div>
        </div>
      }
    >
      <SignUpContent />
    </Suspense>
  );
}
