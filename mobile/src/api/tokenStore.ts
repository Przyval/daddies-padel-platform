// Secure token storage. Uses expo-secure-store on device; falls back to a
// plain in-memory map on web (SecureStore is unavailable there).
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const ACCESS = 'dp_access_token';
const REFRESH = 'dp_refresh_token';

const memory: Record<string, string | null> = {};

async function set(key: string, value: string | null) {
  if (Platform.OS === 'web') {
    memory[key] = value;
    return;
  }
  if (value === null) await SecureStore.deleteItemAsync(key);
  else await SecureStore.setItemAsync(key, value);
}

async function get(key: string): Promise<string | null> {
  if (Platform.OS === 'web') return memory[key] ?? null;
  return SecureStore.getItemAsync(key);
}

export const tokenStore = {
  getAccess: () => get(ACCESS),
  getRefresh: () => get(REFRESH),
  async setTokens(access: string, refresh?: string) {
    await set(ACCESS, access);
    if (refresh !== undefined) await set(REFRESH, refresh);
  },
  async clear() {
    await set(ACCESS, null);
    await set(REFRESH, null);
  },
};
