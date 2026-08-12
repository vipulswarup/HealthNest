import { sendBrevoEmail } from '@/lib/email/brevo';
import { householdInviteEmailContent } from '@/lib/email/templates';

export async function sendHouseholdInviteEmail(input: {
  to: string;
  householdName: string;
  inviterName: string;
  acceptUrl: string;
}): Promise<{ sent: boolean; error?: string }> {
  const content = householdInviteEmailContent(input);
  return sendBrevoEmail({
    to: input.to,
    subject: content.subject,
    html: content.html,
    text: content.text,
  });
}
