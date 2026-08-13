'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';
import { signOut, useSession } from '@/lib/auth/client';
import { useHouseholdContext } from '@/components/households/useHouseholdContext';
import { useToast } from '@/components/ui/ToastProvider';

type AppNavProps = {
  links?: Array<{ href: string; label: string }>;
};

const defaultLinks = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/patients', label: 'Patients' },
  { href: '/health-records', label: 'Health Records' },
  { href: '/medications', label: 'Medications' },
  { href: '/households', label: 'Households' },
];

export default function AppNav({ links = defaultLinks }: AppNavProps) {
  const { data: session } = useSession();
  const { notify } = useToast();
  const pathname = usePathname();
  const router = useRouter();
  const { householdId, households, loading, setActive } = useHouseholdContext();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const isActive = (href: string) => pathname === href || pathname.startsWith(`${href}/`);

  const onSwitch = async (value: string) => {
    setMobileMenuOpen(false);
    if (!value) {
      router.push('/households');
      return;
    }
    try {
      await setActive(value);
      router.refresh();
      if (pathname.startsWith('/patients') || pathname.startsWith('/health-records') || pathname.startsWith('/reports')) {
        window.location.reload();
      }
    } catch (err) {
      notify(err instanceof Error ? err.message : 'Failed to switch household', 'error');
    }
  };

  return (
    <nav className="border-b border-gray-200 bg-white shadow-sm print:hidden" aria-label="Primary navigation">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between gap-4">
          <div className="flex items-center space-x-3 min-w-0">
            <Link href="/dashboard" className="flex items-center space-x-3 shrink-0">
              <Image src="/logo.png" alt="SanoVault Logo" width={40} height={40} className="rounded-full" />
              <span className="text-xl font-bold text-gray-900">SanoVault</span>
            </Link>
            <div className="hidden xl:flex items-center space-x-1 ml-4">
              {links.map((link) => {
                const active = isActive(link.href);
                return (
                  <Link
                    key={link.href}
                    href={link.href}
                    aria-current={active ? 'page' : undefined}
                    className={`px-3 py-2 text-sm font-medium rounded-md ${
                      active ? 'text-[#0175C2] bg-blue-50' : 'text-gray-600 hover:text-[#0175C2]'
                    }`}
                  >
                    {link.label}
                  </Link>
                );
              })}
            </div>
          </div>
          <div className="hidden xl:flex items-center space-x-3 min-w-0">
            {households.length === 0 && !loading ? (
              <Link href="/households" className="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-[#0175C2] hover:bg-blue-50">Create household</Link>
            ) : (
              <>
                <label className="sr-only" htmlFor="household-switcher">Active household</label>
                <select
                  id="household-switcher"
                  className="text-sm border border-gray-300 rounded-md px-2 py-1.5 max-w-[10rem] sm:max-w-[14rem] bg-white text-gray-900"
                  disabled={loading}
                  value={householdId || ''}
                  onChange={(e) => void onSwitch(e.target.value)}
                >
                  {loading && <option value="">Loading households…</option>}
                  {households.map((h) => (
                    <option key={h.id} value={h.id}>{h.name}</option>
                  ))}
                </select>
              </>
            )}
            <span className="text-sm text-gray-700 truncate hidden sm:inline max-w-[10rem]">
              {session?.user?.email || session?.user?.name}
            </span>
            <button
              onClick={() => signOut({ callbackUrl: '/auth/signin' })}
              className="text-sm text-[#0175C2] hover:text-[#015a96] font-medium transition-colors shrink-0"
            >
              Sign out
            </button>
          </div>
          <button
            type="button"
            className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-lg border border-gray-300 text-gray-700 transition-colors hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-[#0175C2] focus:ring-offset-2 xl:hidden"
            aria-controls="mobile-navigation"
            aria-expanded={mobileMenuOpen}
            aria-label={mobileMenuOpen ? 'Close navigation menu' : 'Open navigation menu'}
            onClick={() => setMobileMenuOpen((open) => !open)}
          >
            {mobileMenuOpen ? (
              <svg className="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18 18 6M6 6l12 12" />
              </svg>
            ) : (
              <svg className="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {mobileMenuOpen && (
        <div id="mobile-navigation" className="border-t border-gray-200 bg-white xl:hidden">
          <div className="mx-auto grid max-w-7xl gap-6 px-4 py-5 sm:grid-cols-2 sm:px-6 lg:px-8">
            <div className="space-y-1">
              {links.map((link) => {
                const active = isActive(link.href);
                return (
                  <Link
                    key={link.href}
                    href={link.href}
                    aria-current={active ? 'page' : undefined}
                    onClick={() => setMobileMenuOpen(false)}
                    className={`block rounded-lg px-3 py-3 text-base font-medium ${
                      active
                        ? 'bg-blue-50 text-[#0175C2]'
                        : 'text-gray-700 hover:bg-gray-50 hover:text-[#0175C2]'
                    }`}
                  >
                    {link.label}
                  </Link>
                );
              })}
            </div>

            <div className="space-y-4 border-t border-gray-200 pt-5 sm:border-l sm:border-t-0 sm:pl-6 sm:pt-0">
              <div>
                <label className="block text-sm font-medium text-gray-700" htmlFor="mobile-household-switcher">
                  Active household
                </label>
                <select
                  id="mobile-household-switcher"
                  className="mt-2 w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900"
                  disabled={loading}
                  value={householdId || ''}
                  onChange={(e) => void onSwitch(e.target.value)}
                >
                  {loading && <option value="">Loading households…</option>}
                  {!loading && households.length === 0 && <option value="">No household selected</option>}
                  {households.map((h) => (
                    <option key={h.id} value={h.id}>{h.name}</option>
                  ))}
                </select>
                <Link
                  href="/households"
                  onClick={() => setMobileMenuOpen(false)}
                  className="mt-2 inline-block text-sm font-medium text-[#0175C2] hover:underline"
                >
                  Manage households
                </Link>
              </div>

              <div className="border-t border-gray-200 pt-4">
                <p className="truncate text-sm text-gray-600">
                  {session?.user?.email || session?.user?.name || 'Signed in'}
                </p>
                <button
                  type="button"
                  onClick={() => signOut({ callbackUrl: '/auth/signin' })}
                  className="mt-3 w-full rounded-lg border border-gray-300 px-4 py-2.5 text-left text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Sign out
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </nav>
  );
}
