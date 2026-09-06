const TOKEN_KEY = 'sanovault.session';

export async function getToken() {
  if (typeof localStorage === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export async function setToken(token: string) {
  if (typeof localStorage === 'undefined') return;
  localStorage.setItem(TOKEN_KEY, token);
}

export async function clearToken() {
  if (typeof localStorage === 'undefined') return;
  localStorage.removeItem(TOKEN_KEY);
}
