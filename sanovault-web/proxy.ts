import { auth } from '@/lib/auth/server';
import { NextRequest, NextResponse } from 'next/server';

const protectedPageMiddleware = auth.middleware({ loginUrl: '/auth/signin' });

function isTrustedMutationOrigin(request: NextRequest): boolean {
  const origin = request.headers.get('origin');
  if (!origin) return false;

  const configuredOrigin = process.env.NEXT_PUBLIC_APP_URL
    ? new URL(process.env.NEXT_PUBLIC_APP_URL).origin
    : null;

  if (origin === configuredOrigin) return true;

  // Local development and Vercel preview deployments do not share the public
  // production origin. Their request origin is safe to use for same-origin
  // testing, while production remains pinned to NEXT_PUBLIC_APP_URL.
  return process.env.NODE_ENV !== 'production' || process.env.VERCEL_ENV === 'preview'
    ? origin === request.nextUrl.origin
    : false;
}

export default function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (pathname.startsWith('/api/')) {
    const isUnsafeMethod = !['GET', 'HEAD', 'OPTIONS'].includes(request.method);
    const isAuthRoute = pathname.startsWith('/api/auth/');

    if (isUnsafeMethod && !isAuthRoute && !isTrustedMutationOrigin(request)) {
      return NextResponse.json(
        { error: 'Invalid request origin', code: 'CSRF_VALIDATION_FAILED' },
        { status: 403, headers: { 'Cache-Control': 'no-store' } }
      );
    }

    return NextResponse.next();
  }

  return protectedPageMiddleware(request);
}

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
    // Allow /households/invites/:token without auth so invitees see a pending-invite gate.
    '/households/((?!invites(?:/|$)).*)',
    '/api/:path*',
  ],
};
