import React from 'react';
import {
  Text, View, Pressable, TextInput, ActivityIndicator,
  StyleSheet, ViewStyle, TextStyle, ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing, radius } from './theme';

export function Screen({ children, scroll = true }: { children: React.ReactNode; scroll?: boolean }) {
  const inner = <View style={{ padding: spacing.md, gap: spacing.md, flex: scroll ? undefined : 1 }}>{children}</View>;
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top']}>
      {scroll ? <ScrollView contentContainerStyle={{ paddingBottom: spacing.xl }}>{inner}</ScrollView> : inner}
    </SafeAreaView>
  );
}

export function Card({ children, style }: { children: React.ReactNode; style?: ViewStyle }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function H1({ children }: { children: React.ReactNode }) {
  return <Text style={styles.h1}>{children}</Text>;
}
export function H2({ children }: { children: React.ReactNode }) {
  return <Text style={styles.h2}>{children}</Text>;
}
export function Muted({ children, style }: { children: React.ReactNode; style?: TextStyle }) {
  return <Text style={[styles.muted, style]}>{children}</Text>;
}
export function Body({ children, style }: { children: React.ReactNode; style?: TextStyle }) {
  return <Text style={[styles.body, style]}>{children}</Text>;
}

export function Button({
  title, onPress, loading, variant = 'primary', disabled,
}: { title: string; onPress: () => void; loading?: boolean; variant?: 'primary' | 'outline'; disabled?: boolean }) {
  const isOutline = variant === 'outline';
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        styles.btn,
        isOutline ? styles.btnOutline : styles.btnPrimary,
        (disabled || loading) && { opacity: 0.5 },
        pressed && { opacity: 0.85 },
      ]}
    >
      {loading ? (
        <ActivityIndicator color={isOutline ? colors.primary : '#fff'} />
      ) : (
        <Text style={[styles.btnText, isOutline && { color: colors.primary }]}>{title}</Text>
      )}
    </Pressable>
  );
}

export function Field({
  label, value, onChangeText, secureTextEntry, keyboardType, autoCapitalize, placeholder,
}: {
  label: string; value: string; onChangeText: (t: string) => void;
  secureTextEntry?: boolean; keyboardType?: 'default' | 'email-address' | 'phone-pad';
  autoCapitalize?: 'none' | 'sentences'; placeholder?: string;
}) {
  return (
    <View style={{ gap: spacing.xs }}>
      <Muted>{label}</Muted>
      <TextInput
        style={styles.input}
        value={value}
        onChangeText={onChangeText}
        secureTextEntry={secureTextEntry}
        keyboardType={keyboardType}
        autoCapitalize={autoCapitalize}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
      />
    </View>
  );
}

export function Pill({ text, tone = 'info' }: { text: string; tone?: 'info' | 'success' | 'warning' | 'muted' }) {
  const map = { info: colors.info, success: colors.success, warning: colors.warning, muted: colors.textMuted };
  return (
    <View style={[styles.pill, { backgroundColor: map[tone] + '22' }]}>
      <Text style={{ color: map[tone], fontWeight: '600', fontSize: 12 }}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.surface, borderRadius: radius.lg, padding: spacing.md, gap: spacing.sm,
    borderWidth: 1, borderColor: colors.border },
  h1: { fontSize: 26, fontWeight: '800', color: colors.text },
  h2: { fontSize: 18, fontWeight: '700', color: colors.text },
  muted: { fontSize: 13, color: colors.textMuted },
  body: { fontSize: 15, color: colors.text },
  btn: { paddingVertical: 14, borderRadius: radius.md, alignItems: 'center', justifyContent: 'center' },
  btnPrimary: { backgroundColor: colors.primary },
  btnOutline: { borderWidth: 1.5, borderColor: colors.primary, backgroundColor: 'transparent' },
  btnText: { color: '#fff', fontWeight: '700', fontSize: 15 },
  input: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border,
    borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: 12, fontSize: 15, color: colors.text },
  pill: { alignSelf: 'flex-start', paddingHorizontal: 10, paddingVertical: 4, borderRadius: radius.full },
});
