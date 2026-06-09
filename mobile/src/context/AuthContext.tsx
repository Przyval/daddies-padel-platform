import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { tokenStore } from '../api/tokenStore';
import { Auth } from '../api/endpoints';
import type { UserFull } from '../api/types';

interface AuthState {
  user: UserFull | null;
  loading: boolean;          // initial bootstrap
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (b: { username: string; email: string; phone: string; password: string; referral_code?: string }) => Promise<void>;
  signOut: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const Ctx = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<UserFull | null>(null);
  const [loading, setLoading] = useState(true);

  // Bootstrap: if a token exists, fetch the current user.
  useEffect(() => {
    (async () => {
      const token = await tokenStore.getAccess();
      if (token) {
        try {
          setUser(await Auth.me());
        } catch {
          await tokenStore.clear();
        }
      }
      setLoading(false);
    })();
  }, []);

  const signIn = useCallback(async (email: string, password: string) => {
    const res = await Auth.login(email, password);
    await tokenStore.setTokens(res.access_token, res.refresh_token);
    setUser(res.user);
  }, []);

  const signUp = useCallback(async (b: { username: string; email: string; phone: string; password: string; referral_code?: string }) => {
    const res = await Auth.register(b);
    await tokenStore.setTokens(res.access_token, res.refresh_token);
    setUser(res.user);
  }, []);

  const signOut = useCallback(async () => {
    await tokenStore.clear();
    setUser(null);
  }, []);

  const refreshUser = useCallback(async () => {
    setUser(await Auth.me());
  }, []);

  return (
    <Ctx.Provider value={{ user, loading, signIn, signUp, signOut, refreshUser }}>
      {children}
    </Ctx.Provider>
  );
}

export function useAuth() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth must be used within AuthProvider');
  return v;
}
