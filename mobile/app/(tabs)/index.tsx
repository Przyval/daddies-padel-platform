import React from 'react';
import { View, FlatList } from 'react-native';
import { useRouter } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import { Screen, Card, H1, H2, Muted, Body, Button, Pill } from '../../src/ui';
import { useAuth } from '../../src/context/AuthContext';
import { Community, Sessions } from '../../src/api/endpoints';
import type { SessionSummary } from '../../src/api/types';
import { colors, spacing } from '../../src/theme';

export default function Home() {
  const { user } = useAuth();
  const router = useRouter();
  const lb = useQuery({ queryKey: ['leaderboard', 'chips'], queryFn: () => Community.leaderboard('chips') });
  const upcoming = useQuery({ queryKey: ['sessions', 'upcoming'], queryFn: () => Sessions.list('upcoming') });

  return (
    <Screen>
      <H1>Halo, {user?.name?.split(' ')[0] ?? 'Pemain'} 👋</H1>

      <Card>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <View>
            <Muted>Status</Muted>
            <H2>{user?.member_tier_label ?? 'Guest'}</H2>
            {user?.kta_number ? <Muted>KTA {user.kta_number}</Muted> : null}
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Muted>Chips</Muted>
            <H2>{user?.chips_balance?.toLocaleString() ?? 0}</H2>
          </View>
        </View>
        {!user?.membership_paid && (
          <Button title="Upgrade Membership" variant="outline" onPress={() => router.push('/membership')} />
        )}
      </Card>

      <H2>Sesi Terdekat</H2>
      {upcoming.data?.length ? (
        upcoming.data.slice(0, 3).map((s: SessionSummary) => (
          <Card key={s.id}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Body style={{ fontWeight: '700' }}>{s.title}</Body>
              <Pill text={`${s.confirmed_count}/${s.max_players}`} tone={s.is_full ? 'warning' : 'success'} />
            </View>
            <Muted>{s.location}</Muted>
          </Card>
        ))
      ) : (
        <Muted>Belum ada sesi terjadwal.</Muted>
      )}

      <H2>Top Chips</H2>
      <Card>
        <FlatList
          scrollEnabled={false}
          data={lb.data?.slice(0, 5) ?? []}
          keyExtractor={(r) => String(r.user.id)}
          ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
          renderItem={({ item }) => (
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Body>{item.rank}. {item.user.name}</Body>
              <Body style={{ color: colors.primary, fontWeight: '700' }}>{item.value.toLocaleString()}</Body>
            </View>
          )}
          ListEmptyComponent={<Muted>Memuat…</Muted>}
        />
      </Card>
    </Screen>
  );
}
