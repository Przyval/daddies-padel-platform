import axios, { AxiosError, AxiosRequestConfig } from 'axios';
import Constants from 'expo-constants';
import { tokenStore } from './tokenStore';
import type { ApiEnvelope } from './types';

const API_URL =
  process.env.EXPO_PUBLIC_API_URL ||
  (Constants.expoConfig?.extra as { apiUrl?: string } | undefined)?.apiUrl ||
  'http://127.0.0.1:5000';

export const api = axios.create({
  baseURL: `${API_URL}/api/v1`,
  timeout: 15000,
});

// Attach the access token to every request.
api.interceptors.request.use(async (config) => {
  const token = await tokenStore.getAccess();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// On 401, try a single refresh then replay the original request.
let refreshing: Promise<string | null> | null = null;

async function doRefresh(): Promise<string | null> {
  const refresh = await tokenStore.getRefresh();
  if (!refresh) return null;
  try {
    const res = await axios.post<ApiEnvelope<{ access_token: string }>>(
      `${API_URL}/api/v1/auth/refresh`,
      {},
      { headers: { Authorization: `Bearer ${refresh}` } }
    );
    if (res.data.ok) {
      await tokenStore.setTokens(res.data.data.access_token);
      return res.data.data.access_token;
    }
  } catch {
    /* fall through */
  }
  await tokenStore.clear();
  return null;
}

api.interceptors.response.use(
  (r) => r,
  async (error: AxiosError) => {
    const original = error.config as AxiosRequestConfig & { _retried?: boolean };
    if (error.response?.status === 401 && original && !original._retried) {
      original._retried = true;
      if (!refreshing) refreshing = doRefresh();
      const newToken = await refreshing;
      refreshing = null;
      if (newToken) {
        original.headers = { ...original.headers, Authorization: `Bearer ${newToken}` };
        return api(original);
      }
    }
    return Promise.reject(error);
  }
);

/** Unwrap the {ok,data|error} envelope; throw a readable Error on failure. */
export async function unwrap<T>(p: Promise<{ data: ApiEnvelope<T> }>): Promise<T> {
  try {
    const res = await p;
    if (res.data.ok) return res.data.data;
    throw new Error(res.data.error.message);
  } catch (e) {
    if (axios.isAxiosError(e)) {
      const body = e.response?.data as ApiEnvelope<unknown> | undefined;
      if (body && !body.ok) throw new Error(body.error.message);
      throw new Error(e.message);
    }
    throw e;
  }
}

export { API_URL };
