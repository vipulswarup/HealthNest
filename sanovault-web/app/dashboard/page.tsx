'use client';

import { useSession } from '@/lib/auth/client';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import AppNav from '@/components/layout/AppNav';

type PendingInvite = {
  id: string;
  householdName?: string;
  token: string;
  invitedByName?: string;
};

export default function Dashboard() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [pending, setPending] = useState<PendingInvite[]>([]);

  useEffect(() => {
    if (status === 'loading') return;
    if (!session) {
      router.push('/auth/signin');
      return;
    }
    void fetch('/api/households/invites/pending')
      .then((r) => (r.ok ? r.json() : []))
      .then((data) => setPending(Array.isArray(data) ? data : []))
      .catch(() => setPending([]));
  }, [session?.user?.id, status, router]);

  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!session) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <AppNav />

      <main className="max-w-7xl mx-auto py-8 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          {pending.length > 0 && (
            <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6">
              <p className="font-medium text-amber-900 mb-2">Pending household invitations</p>
              <ul className="space-y-2">
                {pending.map((invite) => (
                  <li key={invite.id} className="flex items-center justify-between gap-3 text-sm">
                    <span>
                      {invite.invitedByName || 'Someone'} invited you to{' '}
                      <strong>{invite.householdName || 'a household'}</strong>
                    </span>
                    <Link
                      href={`/households/invites/${invite.token}`}
                      className="text-[#0175C2] font-medium hover:underline shrink-0"
                    >
                      Review
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          )}

          <div className="bg-white rounded-2xl shadow-xl p-8 mb-6">
            <div className="text-center mb-8">
              <h2 className="text-3xl font-bold text-gray-900 mb-2">
                Welcome{session.user?.firstName ? `, ${session.user.firstName}` : ''}!
              </h2>
              <p className="text-gray-600">
                Your health record management dashboard is coming soon.
              </p>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <Link href="/health-records" className="bg-gradient-to-br from-blue-50 to-indigo-50 p-6 rounded-xl shadow-md hover:shadow-lg transition-shadow cursor-pointer border border-blue-100">
                <h3 className="font-semibold text-gray-900 text-lg mb-2">Health Records</h3>
                <p className="text-sm text-gray-600">Manage your health records and documents</p>
              </Link>
              <Link href="/patients" className="bg-gradient-to-br from-green-50 to-emerald-50 p-6 rounded-xl shadow-md hover:shadow-lg transition-shadow cursor-pointer border border-green-100">
                <h3 className="font-semibold text-gray-900 text-lg mb-2">Patients</h3>
                <p className="text-sm text-gray-600">Manage family members&apos; health profiles</p>
              </Link>
              <Link href="/households" className="bg-gradient-to-br from-slate-50 to-slate-100 p-6 rounded-xl shadow-md hover:shadow-lg transition-shadow cursor-pointer border border-slate-200">
                <h3 className="font-semibold text-gray-900 text-lg mb-2">Households</h3>
                <p className="text-sm text-gray-600">Invite family and share a vault</p>
              </Link>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
