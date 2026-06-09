import React, { useState } from 'react';
import { View, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Screen, Card, H1, H2, Muted, Body, Button, Pill, Field } from '../src/ui';
import { Membership } from '../src/api/endpoints';
import { useAuth } from '../src/context/AuthContext';
import { colors, spacing } from '../src/theme';

function ProgressRow({ label, done, hint }: { label: string; done: boolean; hint: string }) {
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
      <View style={{ flexDirection: 'row', gap: spacing.sm, alignItems: 'center', flex: 1 }}>
        <Body style={{ color: done ? colors.success : colors.textMuted }}>{done ? '✓' : '○'}</Body>
        <Body>{label}</Body>
      </View>
      <Muted>{hint}</Muted>
    </View>
  );
}

export default function MembershipScreen() {
  const qc = useQueryClient();
  const router = useRouter();
  const { refreshUser } = useAuth();
  const [code, setCode] = useState('');
  const { data, isLoading } = useQuery({ queryKey: ['membership'], queryFn: () => Membership.status() });

  const upgrade = useMutation({
    mutationFn: () => Membership.upgrade(code.trim() || undefined),
    onSuccess: async () => {
      await refreshUser();
      qc.invalidateQueries({ queryKey: ['membership'] });
      Alert.alert('Membership aktif!', 'Selamat, kamu sekarang Member.');
      router.back();
    },
    onError: (e) => Alert.alert('Gagal', e instanceof Error ? e.message : 'Coba lagi'),
  });

  if (isLoading || !data) {
    return <Screen><Muted>Memuat…</Muted></Screen>;
  }

  const p = data.progress;
  return (
    <Screen>
      <Card style={{ alignItems: 'center', gap: spacing.sm }}>
        <Body style={{ fontSize: 40 }}>✅</Body>
        <Muted>Status Membership</Muted>
        <H1>{data.member_tier_label}</H1>
        {data.kta_number ? <Muted>KTA {data.kta_number}</Muted> : null}
      </Card>

      <H2>Progres Membership</H2>
      <Card>
        <ProgressRow label="Main minimal 5 kali" done={p.games_played >= p.games_required}
          hint={`${p.games_played}/${p.games_required}`} />
        <ProgressRow label="Bayar iuran member" done={data.membership_paid}
          hint={data.membership_paid ? 'Sudah' : 'Belum'} />
        <ProgressRow label="Main 20+ kali (Elite)" done={p.games_played >= p.games_required_elite}
          hint={`${p.games_played}/${p.games_required_elite}`} />
        <ProgressRow label="Kumpulkan 10.000 chips (Elite)" done={p.chips_balance >= p.chips_required_elite}
          hint={`${p.chips_balance.toLocaleString()}/${p.chips_required_elite.toLocaleString()}`} />
      </Card>

      <H2>Benefits</H2>
      <Card>
        <Pill text="MEMBER" tone="success" />
        <Muted>KTA Digital · Join sesi & turnamen · Leaderboard · Daddies Chips</Muted>
        <View style={{ height: spacing.sm }} />
        <Pill text="ELITE" tone="warning" />
        <Muted>Semua benefit Member + Exclusive merch · Priority booking · Gold KTA</Muted>
      </Card>

      {!data.membership_paid && (
        <Card>
          <Field label="Kode Referral (opsional, Rp 200K)" value={code} onChangeText={setCode}
            autoCapitalize="none" placeholder="DPC-XXXX" />
          <Button title="Aktifkan Membership" onPress={() => upgrade.mutate()} loading={upgrade.isPending} />
        </Card>
      )}
    </Screen>
  );
}
