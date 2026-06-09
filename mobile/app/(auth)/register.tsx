import React, { useState } from 'react';
import { View } from 'react-native';
import { Link } from 'expo-router';
import { Screen, Card, H1, Muted, Button, Field, Body } from '../../src/ui';
import { useAuth } from '../../src/context/AuthContext';
import { colors, spacing } from '../../src/theme';

export default function Register() {
  const { signUp } = useAuth();
  const [form, setForm] = useState({ username: '', email: '', phone: '', password: '', referral_code: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const set = (k: keyof typeof form) => (v: string) => setForm((f) => ({ ...f, [k]: v }));

  async function onSubmit() {
    setError(null);
    setLoading(true);
    try {
      await signUp({
        username: form.username.trim(),
        email: form.email.trim().toLowerCase(),
        phone: form.phone.trim(),
        password: form.password,
        referral_code: form.referral_code.trim() || undefined,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Registrasi gagal');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen>
      <View style={{ height: spacing.lg }} />
      <H1>Buat Akun</H1>
      <Muted>Gabung komunitas Daddies Padel.</Muted>

      <Card style={{ marginTop: spacing.md }}>
        <Field label="Nama" value={form.username} onChangeText={set('username')} placeholder="Nama lengkap" />
        <Field label="Email" value={form.email} onChangeText={set('email')}
          keyboardType="email-address" autoCapitalize="none" placeholder="kamu@email.com" />
        <Field label="No. HP" value={form.phone} onChangeText={set('phone')}
          keyboardType="phone-pad" placeholder="0812..." />
        <Field label="Password" value={form.password} onChangeText={set('password')}
          secureTextEntry placeholder="min. 6 karakter" />
        <Field label="Kode Referral (opsional)" value={form.referral_code} onChangeText={set('referral_code')}
          autoCapitalize="none" placeholder="DPC-XXXX" />
        {error && <Body style={{ color: colors.danger }}>{error}</Body>}
        <Button title="Daftar" onPress={onSubmit} loading={loading} />
      </Card>

      <View style={{ flexDirection: 'row', justifyContent: 'center', gap: 6, marginTop: spacing.md }}>
        <Muted>Sudah punya akun?</Muted>
        <Link href="/(auth)/login" style={{ color: colors.primary, fontWeight: '700' }}>
          Masuk
        </Link>
      </View>
    </Screen>
  );
}
