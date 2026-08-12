import { Resend } from 'resend';

function getResendClient() {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) return null;
  return new Resend(apiKey);
}

export async function sendHouseholdInviteEmail(input: {
  to: string;
  householdName: string;
  inviterName: string;
  acceptUrl: string;
}): Promise<{ sent: boolean; error?: string }> {
  const from = process.env.EMAIL_FROM || 'SanoVault <onboarding@resend.dev>';
  const client = getResendClient();
  if (!client) {
    console.warn('RESEND_API_KEY not set; skipping invite email');
    return { sent: false, error: 'Email not configured' };
  }

  try {
    const { error } = await client.emails.send({
      from,
      to: input.to,
      subject: `You're invited to join ${input.householdName} on SanoVault`,
      html: `
        <p>${input.inviterName} invited you to join the household <strong>${input.householdName}</strong> on SanoVault.</p>
        <p>You'll be able to view and manage shared health records for that household.</p>
        <p><a href="${input.acceptUrl}">Accept invitation</a></p>
        <p>If you didn't expect this, you can ignore this email.</p>
      `,
      text: `${input.inviterName} invited you to join ${input.householdName} on SanoVault.\n\nAccept: ${input.acceptUrl}`,
    });
    if (error) return { sent: false, error: error.message };
    return { sent: true };
  } catch (err) {
    return { sent: false, error: err instanceof Error ? err.message : 'Failed to send email' };
  }
}
