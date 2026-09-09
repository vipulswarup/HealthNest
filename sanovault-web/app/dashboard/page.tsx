import { redirect } from 'next/navigation';
import { DashboardHome } from '@/components/dashboard/DashboardHome';
import { getAuthenticatedUser, getCurrentUser } from '@/lib/auth/session';
import { loadDashboardHome } from '@/lib/dashboard/load-home';

export default async function DashboardPage() {
  const authed = await getAuthenticatedUser();
  if (!authed) redirect('/auth/signin');
  const user = await getCurrentUser();
  if (!user) redirect('/beta-acknowledgement');

  const home = await loadDashboardHome(user.id, user.email);
  const firstName = user.name.trim().split(/\s+/)[0] || '';
  return <DashboardHome firstName={firstName} initial={home} />;
}
