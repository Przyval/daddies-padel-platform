import React, { useState } from 'react';
import { View } from 'react-native';
import { Link } from 'expo-router';
import { Screen, Card, H1, Muted, Button, Field, Body } from '../../src/ui';
import { useAuth } from '../../src/context/AuthContext';
import { colors, spacing } from '../../src/theme';

export default function Login() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit() {
    setError(null);
    setLoading(true);
    try {
      await signIn(email.trim().toLowerCase(), password);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Login gagal');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen>
      <View style={{ height: spacing.xl }} />
      <H1>Daddies Padel</H1>
      <Muted>Masuk untuk lanjut main.</Muted>

      <Card style={{ marginTop: spacing.md }}>
        <Field label="Email" value={email} onChangeText={setEmail}
          keyboardType="email-address" autoCapitalize="none" placeholder="kamu@email.com" />
        <Field label="Password" value={password} onChangeText={setPassword}
          secureTextEntry placeholder="••••••" />
        {error && <Body style={{ color: colors.danger }}>{error}</Body>}
        <Button title="Masuk" onPress={onSubmit} loading={loading} />
      </Card>

      <View style={{ flexDirection: 'row', justifyContent: 'center', gap: 6, marginTop: spacing.md }}>
        <Muted>Belum punya akun?</Muted>
        <Link href="/(auth)/register" style={{ color: colors.primary, fontWeight: '700' }}>
          Daftar
        </Link>
      </View>
    </Screen>
  );
}
