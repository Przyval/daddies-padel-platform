import React from 'react';
import { View } from 'react-native';
import { useRouter } from 'expo-router';
import { Screen, Card, H1, H2, Muted, Body, Button, Pill } from '../../src/ui';
import { useAuth } from '../../src/context/AuthContext';
import { spacing } from '../../src/theme';

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <View style={{ alignItems: 'center', flex: 1 }}>
      <H2>{value}</H2>
      <Muted>{label}</Muted>
    </View>
  );
}

export default function Profile() {
  const { user, signOut } = useAuth();
  const router = useRouter();
  if (!user) return null;

  return (
    <Screen>
      <H1>{user.name}</H1>
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <Pill text={user.member_tier_label} tone="success" />
        {user.kta_number ? <Pill text={`KTA ${user.kta_number}`} tone="info" /> : null}
      </View>

      <Card>
        <View style={{ flexDirection: 'row' }}>
          <Stat label="Sesi" value={user.stats.sessions_played} />
          <Stat label="Turnamen" value={user.stats.tournaments_played} />
          <Stat label="Game" value={user.stats.total_games} />
        </View>
      </Card>

      <Card>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          <Muted>Chips</Muted><Body style={{ fontWeight: '700' }}>{user.chips_balance.toLocaleString()}</Body>
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          <Muted>Streak</Muted><Body style={{ fontWeight: '700' }}>{user.streak.current} minggu</Body>
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          <Muted>Kode Referral</Muted><Body style={{ fontWeight: '700' }}>{user.referral_code || '-'}</Body>
        </View>
      </Card>

      {!user.membership_paid && (
        <Button title="Upgrade Membership" onPress={() => router.push('/membership')} />
      )}
      <Button title="Keluar" variant="outline" onPress={signOut} />
    </Screen>
  );
}
