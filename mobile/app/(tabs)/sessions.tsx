import React from 'react';
import { View, FlatList, Alert } from 'react-native';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Screen, Card, H2, Muted, Body, Button, Pill } from '../../src/ui';
import { Sessions } from '../../src/api/endpoints';
import { spacing } from '../../src/theme';
import type { SessionSummary } from '../../src/api/types';

export default function SessionsScreen() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['sessions', 'upcoming'],
    queryFn: () => Sessions.list('upcoming'),
  });

  const join = useMutation({
    mutationFn: (id: number) => Sessions.join(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['sessions'] });
      Alert.alert('Berhasil', 'Kamu sudah join sesi ini. Lanjut bayar di detail.');
    },
    onError: (e) => Alert.alert('Gagal', e instanceof Error ? e.message : 'Coba lagi'),
  });

  function renderItem({ item }: { item: SessionSummary }) {
    return (
      <Card>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <Body style={{ fontWeight: '700', fontSize: 16 }}>{item.title}</Body>
          <Pill text={`${item.confirmed_count}/${item.max_players}`} tone={item.is_full ? 'warning' : 'success'} />
        </View>
        <Muted>{item.location}</Muted>
        {item.price > 0 && <Muted>Rp {item.price.toLocaleString()}</Muted>}
        {item.my_status ? (
          <Pill text={`Status: ${item.my_status}`} tone="info" />
        ) : (
          <Button title={item.is_full ? 'Masuk Waitlist' : 'Join Sesi'}
            onPress={() => join.mutate(item.id)} loading={join.isPending} />
        )}
      </Card>
    );
  }

  return (
    <Screen scroll={false}>
      <H2>Sesi Mendatang</H2>
      <FlatList
        data={data ?? []}
        keyExtractor={(s) => String(s.id)}
        renderItem={renderItem}
        ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
        ListEmptyComponent={<Muted>{isLoading ? 'Memuat…' : 'Belum ada sesi.'}</Muted>}
        contentContainerStyle={{ paddingBottom: spacing.xl, gap: spacing.sm }}
      />
    </Screen>
  );
}
