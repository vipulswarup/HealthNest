export function whatsappShareHref(text: string) {
  return `https://wa.me/?text=${encodeURIComponent(text)}`;
}

export function familyReentryMessage(origin: string) {
  return `Open SanoVault on this phone: ${origin.replace(/\/$/, '')}/auth/signin`;
}
