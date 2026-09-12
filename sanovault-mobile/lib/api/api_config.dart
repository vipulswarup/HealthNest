const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://www.sanovault.com',
);

const nativeAuthScheme = 'sanovault';
const betaAcknowledgementVersion = '2026-08-12';
const betaAcknowledgementTitle = 'One thing before you continue';
const betaAcknowledgementText =
    'SanoVault is a private family folder in beta. It is not a hospital system, and it is not certified under HIPAA, GDPR, or India’s DPDP Act. You are choosing to keep family records here anyway.';
