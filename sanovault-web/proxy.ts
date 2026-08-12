import { auth } from '@/lib/auth/server';

export default auth.middleware({ loginUrl: '/auth/signin' });

export const config = {
  matcher: [
    '/dashboard',
    '/dashboard/:path*',
    '/patients',
    '/patients/:path*',
    '/health-records',
    '/health-records/:path*',
    '/documents',
    '/documents/:path*',
    '/reports',
    '/reports/:path*',
    '/households',
    '/households/:path*',
  ],
};
