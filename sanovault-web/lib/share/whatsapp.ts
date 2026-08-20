export function whatsappShareHref(text: string) {
  return `https://wa.me/?text=${encodeURIComponent(text)}`;
}

export function familyReentryMessage(origin: string) {
  return `Open SanoVault on this phone: ${origin.replace(/\/$/, '')}/auth/signin`;
}

export function familyInviteMessage(inviterName: string, acceptUrl: string) {
  return `${inviterName} invited you to the family health folder on SanoVault. Tap to join with Google: ${acceptUrl}`;
}
