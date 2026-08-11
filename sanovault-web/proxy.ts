import { auth } from '@/lib/auth/server';

export default auth.middleware({ loginUrl: '/auth/signin' });

export const config = {
  matcher: ['/dashboard/:path*', '/patients/:path*', '/health-records/:path*', '/documents/:path*', '/reports/:path*'],
};
