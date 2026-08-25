import { getToken } from './session';

export const API_URL = (process.env.EXPO_PUBLIC_API_URL || 'https://www.sanovault.com').replace(/\/$/, '');

export async function api(path: string, init: RequestInit = {}) {
  const token = await getToken();
  const headers = new Headers(init.headers);
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (init.body && !(init.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }
  const response = await fetch(`${API_URL}${path}`, { ...init, headers });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(typeof body.error === 'string' ? body.error : 'Request failed');
  }
  return body;
}

export async function uploadFile(uri: string, name: string, type: string) {
  const form = new FormData();
  form.append('file', { uri, name, type } as unknown as Blob);
  return api('/api/documents/upload', { method: 'POST', body: form });
}
