import React, { useState } from 'react';
import { View, TextInput, StyleSheet, Alert } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Screen, Card, H1, H2, Muted, Body, Button, Pill } from '../../src/ui';
import { useAuth } from '../../src/context/AuthContext';
import { Tournaments } from '../../src/api/endpoints';
import { colors, spacing, radius } from '../../src/theme';
import type { MatchView, RoundView, StandingRow } from '../../src/api/types';

function teamNames(team: MatchView['team1']) {
  return team.filter(Boolean).map((p) => p!.first_name).join(' & ') || '—';
}

function MatchCard({ tid, match, canScore }: { tid: number; match: MatchView; canScore: boolean }) {
  const qc = useQueryClient();
  const [t1, setT1] = useState(String(match.score_team1 || ''));
  const [t2, setT2] = useState(String(match.score_team2 || ''));

  const save = useMutation({
    mutationFn: () => Tournaments.score(tid, match.id, Number(t1) || 0, Number(t2) || 0),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tournament', tid] }),
    onError: (e) => Alert.alert('Gagal', e instanceof Error ? e.message : 'Coba lagi'),
  });

  const done = match.status === 'completed';
  return (
    <Card>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Muted>Court {match.court}</Muted>
        <Pill text={done ? 'Selesai' : 'Berlangsung'} tone={done ? 'success' : 'info'} />
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <Body style={{ flex: 1, fontWeight: '600' }}>{teamNames(match.team1)}</Body>
        {canScore && !done ? (
          <TextInput style={s.score} value={t1} onChangeText={setT1} keyboardType="number-pad" maxLength={2} />
        ) : (
          <Body style={s.scoreText}>{match.score_team1}</Body>
        )}
        <Body style={{ marginHorizontal: 6, color: colors.textMuted }}>vs</Body>
        {canScore && !done ? (
          <TextInput style={s.score} value={t2} onChangeText={setT2} keyboardType="number-pad" maxLength={2} />
        ) : (
          <Body style={s.scoreText}>{match.score_team2}</Body>
        )}
        <Body style={{ flex: 1, textAlign: 'right', fontWeight: '600' }}>{teamNames(match.team2)}</Body>
      </View>
      {canScore && (
        <Button title={done ? 'Ubah Skor' : 'Simpan Skor'} variant="outline"
          onPress={() => save.mutate()} loading={save.isPending} />
      )}
    </Card>
  );
}

export default function TournamentDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const tid = Number(id);
  const qc = useQueryClient();
  const { user } = useAuth();
  const { data, isLoading } = useQuery({
    queryKey: ['tournament', tid],
    queryFn: () => Tournaments.detail(tid),
  });

  const next = useMutation({
    mutationFn: () => Tournaments.nextRound(tid),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tournament', tid] }),
    onError: (e) => Alert.alert('Belum bisa', e instanceof Error ? e.message : 'Coba lagi'),
  });
  const finish = useMutation({
    mutationFn: () => Tournaments.complete(tid),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['tournament', tid] }); Alert.alert('Selesai', 'Turnamen ditutup, chips dibagikan.'); },
    onError: (e) => Alert.alert('Gagal', e instanceof Error ? e.message : 'Coba lagi'),
  });

  if (isLoading || !data) return <Screen><Muted>Memuat…</Muted></Screen>;

  const canManage = !!user && (user.role === 'admin' || data.created_by === user.id);
  const currentRound = data.rounds.find((r: RoundView) => r.round_number === data.current_round) ?? data.rounds[data.rounds.length - 1];

  return (
    <Screen>
      <H1>{data.format_icon} {data.name}</H1>
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <Pill text={data.status} tone={data.status === 'completed' ? 'muted' : 'success'} />
        <Pill text={`${data.format_label}`} tone="info" />
        <Pill text={`Ronde ${data.current_round}/${data.total_rounds}`} tone="muted" />
      </View>

      <H2>Klasemen</H2>
      <Card>
        {data.standings.map((row: StandingRow) => (
          <View key={row.participant.id} style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 3 }}>
            <Body>{row.rank}. {row.participant.name}</Body>
            <Body style={{ fontWeight: '700' }}>
              {row.points} <Muted>({row.wins}-{row.losses}-{row.ties})</Muted>
            </Body>
          </View>
        ))}
        {data.standings.length === 0 && <Muted>Belum ada hasil.</Muted>}
      </Card>

      {currentRound && (
        <>
          <H2>Ronde {currentRound.round_number}</H2>
          {currentRound.matches.map((m: MatchView) => (
            <MatchCard key={m.id} tid={tid} match={m} canScore={canManage} />
          ))}
        </>
      )}

      {canManage && data.status !== 'completed' && (
        <View style={{ gap: spacing.sm, marginTop: spacing.sm }}>
          <Button title="Ronde Berikutnya" onPress={() => next.mutate()} loading={next.isPending} />
          <Button title="Selesaikan Turnamen" variant="outline" onPress={() => finish.mutate()} loading={finish.isPending} />
        </View>
      )}
    </Screen>
  );
}

const s = StyleSheet.create({
  score: { width: 44, textAlign: 'center', borderWidth: 1, borderColor: colors.border,
    borderRadius: radius.sm, paddingVertical: 6, fontSize: 16, color: colors.text, backgroundColor: colors.surface },
  scoreText: { width: 44, textAlign: 'center', fontSize: 18, fontWeight: '800', color: colors.primary },
});
