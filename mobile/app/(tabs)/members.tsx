import React, { useState } from 'react';
import { View, FlatList } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { Screen, Card, H2, Muted, Body, Field, Pill } from '../../src/ui';
import { Community } from '../../src/api/endpoints';
import { spacing } from '../../src/theme';

export default function Members() {
  const [q, setQ] = useState('');
  const { data, isLoading } = useQuery({
    queryKey: ['members', q],
    queryFn: () => Community.members(q),
  });

  return (
    <Screen scroll={false}>
      <H2>Anggota</H2>
      <Field label="Cari" value={q} onChangeText={setQ} autoCapitalize="none" placeholder="Nama anggota…" />
      <FlatList
        data={data ?? []}
        keyExtractor={(u) => String(u.id)}
        ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
        renderItem={({ item }) => (
          <Card>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
              <Body style={{ fontWeight: '700' }}>{item.name}</Body>
              <Pill text={item.member_tier_label} tone="info" />
            </View>
            {item.nickname ? <Muted>“{item.nickname}”</Muted> : null}
          </Card>
        )}
        ListEmptyComponent={<Muted>{isLoading ? 'Memuat…' : 'Tidak ada anggota.'}</Muted>}
        contentContainerStyle={{ paddingBottom: spacing.xl, gap: spacing.sm }}
      />
    </Screen>
  );
}
