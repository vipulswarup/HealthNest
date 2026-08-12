'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { signOut, useSession } from '@/lib/auth/client';
import { useHouseholdContext } from '@/components/households/useHouseholdContext';

type AppNavProps = {
  links?: Array<{ href: string; label: string }>;
};

const defaultLinks = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/patients', label: 'Patients' },
  { href: '/health-records', label: 'Health Records' },
  { href: '/households', label: 'Households' },
];

export default function AppNav({ links = defaultLinks }: AppNavProps) {
  const { data: session } = useSession();
  const pathname = usePathname();
  const router = useRouter();
  const { householdId, households, loading, setActive } = useHouseholdContext();

  const onSwitch = async (value: string) => {
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
      alert(err instanceof Error ? err.message : 'Failed to switch context');
    }
  };

  return (
    <nav className="bg-white shadow-lg">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 gap-4">
          <div className="flex items-center space-x-3 min-w-0">
            <Link href="/dashboard" className="flex items-center space-x-3 shrink-0">
              <Image src="/logo.png" alt="SanoVault Logo" width={40} height={40} className="rounded-full" />
              <span className="text-xl font-bold text-gray-900 hidden sm:inline">SanoVault</span>
            </Link>
            <div className="hidden md:flex items-center space-x-1 ml-4">
              {links.map((link) => {
                const active = pathname === link.href || pathname.startsWith(`${link.href}/`);
                return (
                  <Link
                    key={link.href}
                    href={link.href}
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
          <div className="flex items-center space-x-3 min-w-0">
            <label className="sr-only" htmlFor="household-switcher">
              Active household
            </label>
            <select
              id="household-switcher"
              className="text-sm border border-gray-300 rounded-md px-2 py-1.5 max-w-[10rem] sm:max-w-[14rem] bg-white text-gray-900"
              disabled={loading}
              value={householdId || ''}
              onChange={(e) => void onSwitch(e.target.value)}
            >
              {households.length === 0 ? (
                <option value="">Create a household…</option>
              ) : (
                households.map((h) => (
                  <option key={h.id} value={h.id}>
                    {h.name}
                  </option>
                ))
              )}
            </select>
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
        </div>
      </div>
    </nav>
  );
}
