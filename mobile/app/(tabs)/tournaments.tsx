import React from 'react';
import { View, FlatList, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import { Screen, Card, H2, Muted, Body, Pill } from '../../src/ui';
import { Tournaments } from '../../src/api/endpoints';
import { spacing } from '../../src/theme';
import type { TournamentSummary } from '../../src/api/types';

const STATUS_TONE: Record<string, 'success' | 'info' | 'muted' | 'warning'> = {
  playing: 'success', open: 'info', completed: 'muted', draft: 'warning',
};

export default function TournamentsScreen() {
  const router = useRouter();
  const { data, isLoading } = useQuery({
    queryKey: ['tournaments'],
    queryFn: () => Tournaments.list(),
  });

  function renderItem({ item }: { item: TournamentSummary }) {
    return (
      <Pressable onPress={() => router.push(`/tournament/${item.id}`)}>
        <Card>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
            <Body style={{ fontWeight: '700', fontSize: 16 }}>{item.format_icon} {item.name}</Body>
            <Pill text={item.status} tone={STATUS_TONE[item.status] ?? 'muted'} />
          </View>
          <Muted>{item.format_label} · {item.participant_count} pemain · Ronde {item.current_round}/{item.total_rounds}</Muted>
        </Card>
      </Pressable>
    );
  }

  return (
    <Screen scroll={false}>
      <H2>Turnamen</H2>
      <FlatList
        data={data ?? []}
        keyExtractor={(t) => String(t.id)}
        renderItem={renderItem}
        ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
        ListEmptyComponent={<Muted>{isLoading ? 'Memuat…' : 'Belum ada turnamen.'}</Muted>}
        contentContainerStyle={{ paddingBottom: spacing.xl, gap: spacing.sm }}
      />
    </Screen>
  );
}
