const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://www.sanovault.com',
);

const nativeAuthScheme = 'sanovault';
const betaAcknowledgementVersion = '2026-09-25';
const betaAcknowledgementTitle = 'One thing before you continue';
const betaAcknowledgementText =
    'SanoVault is a family health-record folder in beta, operated by Argali Knowledge Services Private Limited. Only add records you are authorised to manage and share with your family. Verify extracted information against the original and consult a clinician for medical decisions. Read our privacy policy for how records are processed, shared and deleted.';
const groqAiConsentText =
    'When enabled, SanoVault sends text extracted from health documents and, for some tasks, document or medicine images to Groq, an external AI provider, to read, organise, classify and summarise them. Groq may process data outside your country. AI processing is optional; turning it off does not stop file storage or manual record entry.';
const groqAiConsentAcknowledgement =
    'I choose whether SanoVault may send my health document text and relevant images to Groq for AI processing. I understand Groq is an external provider and may process data outside my country. I can withdraw this choice in Settings.';
