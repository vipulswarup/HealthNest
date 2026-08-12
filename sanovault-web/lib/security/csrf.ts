export type CsrfOriginContext = {
  origin: string | null;
  requestOrigin: string;
  configuredAppUrl?: string;
  nodeEnv?: string;
  vercelEnv?: string;
};

/**
 * Validates the Origin header for cookie-authenticated mutations. Production
 * accepts only the configured public app origin; local and preview deployments
 * may use their own same-origin address for testing.
 */
export function hasTrustedMutationOrigin({
  origin,
  requestOrigin,
  configuredAppUrl,
  nodeEnv,
  vercelEnv,
}: CsrfOriginContext): boolean {
  if (!origin) return false;

  let configuredOrigin: string | null = null;
  if (configuredAppUrl) {
    try {
      configuredOrigin = new URL(configuredAppUrl).origin;
    } catch {
      // A malformed configuration must never broaden the set of trusted origins.
      return false;
    }
  }

  if (origin === configuredOrigin) return true;

  return (nodeEnv !== 'production' || vercelEnv === 'preview') && origin === requestOrigin;
}
