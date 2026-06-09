import React from 'react';
import { Text } from 'react-native';
import { Tabs } from 'expo-router';
import { colors } from '../../src/theme';

function icon(emoji: string) {
  return ({ color }: { color: string }) => <Text style={{ fontSize: 20, color }}>{emoji}</Text>;
}

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerStyle: { backgroundColor: colors.surface },
        headerTitleStyle: { fontWeight: '800', color: colors.text },
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'Beranda', tabBarIcon: icon('🏠') }} />
      <Tabs.Screen name="sessions" options={{ title: 'Sesi', tabBarIcon: icon('🎾') }} />
      <Tabs.Screen name="members" options={{ title: 'Anggota', tabBarIcon: icon('👥') }} />
      <Tabs.Screen name="profile" options={{ title: 'Profil', tabBarIcon: icon('👤') }} />
    </Tabs>
  );
}
