import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daddies_app/core/providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifSessionCreated = true;
  bool _notifPayment = true;
  bool _notifReminder = true;

  static const _keySessionCreated = 'notif_session_created';
  static const _keyPayment = 'notif_payment';
  static const _keyReminder = 'notif_reminder';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifSessionCreated = prefs.getBool(_keySessionCreated) ?? true;
      _notifPayment = prefs.getBool(_keyPayment) ?? true;
      _notifReminder = prefs.getBool(_keyReminder) ?? true;
    });
  }

  Future<void> _setNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProv = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Appearance section
          _SectionHeader(title: 'Tampilan', colorScheme: colorScheme),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Mode Gelap',
            subtitle: themeProv.isDark ? 'Aktif' : 'Nonaktif',
            trailing: Switch.adaptive(
              value: themeProv.isDark,
              activeTrackColor: colorScheme.primary,
              onChanged: (_) => themeProv.toggleDarkMode(),
            ),
            colorScheme: colorScheme,
          ),
          _SettingsTile(
            icon: Icons.color_lens_outlined,
            title: 'Tema Sistem',
            subtitle: 'Ikuti pengaturan perangkat',
            trailing: Switch.adaptive(
              value: themeProv.themeMode == ThemeMode.system,
              activeTrackColor: colorScheme.primary,
              onChanged: (on) => themeProv.setThemeMode(
                on ? ThemeMode.system : ThemeMode.light,
              ),
            ),
            colorScheme: colorScheme,
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // Notifications section
          _SectionHeader(title: 'Notifikasi', colorScheme: colorScheme),
          _SettingsTile(
            icon: Icons.event_available_outlined,
            title: 'Sesi Baru',
            subtitle: 'Notifikasi saat ada sesi baru dibuat',
            trailing: Switch.adaptive(
              value: _notifSessionCreated,
              activeTrackColor: colorScheme.primary,
              onChanged: (v) {
                setState(() => _notifSessionCreated = v);
                _setNotifPref(_keySessionCreated, v);
              },
            ),
            colorScheme: colorScheme,
          ),
          _SettingsTile(
            icon: Icons.payment_outlined,
            title: 'Pembayaran',
            subtitle: 'Status verifikasi pembayaran',
            trailing: Switch.adaptive(
              value: _notifPayment,
              activeTrackColor: colorScheme.primary,
              onChanged: (v) {
                setState(() => _notifPayment = v);
                _setNotifPref(_keyPayment, v);
              },
            ),
            colorScheme: colorScheme,
          ),
          _SettingsTile(
            icon: Icons.alarm_outlined,
            title: 'Pengingat',
            subtitle: 'Reminder sebelum sesi dimulai',
            trailing: Switch.adaptive(
              value: _notifReminder,
              activeTrackColor: colorScheme.primary,
              onChanged: (v) {
                setState(() => _notifReminder = v);
                _setNotifPref(_keyReminder, v);
              },
            ),
            colorScheme: colorScheme,
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // About section
          _SectionHeader(title: 'Tentang', colorScheme: colorScheme),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Versi Aplikasi',
            subtitle: '1.0.0',
            colorScheme: colorScheme,
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Syarat & Ketentuan',
            subtitle: 'Baca syarat penggunaan',
            onTap: () => _showInfoDialog(
              context,
              'Syarat & Ketentuan',
              'Dengan menggunakan aplikasi Daddies Padel Community, '
                  'Anda menyetujui syarat dan ketentuan yang berlaku. '
                  'Aplikasi ini digunakan untuk mengelola komunitas padel '
                  'dan semua data ditangani sesuai kebijakan privasi kami.',
            ),
            colorScheme: colorScheme,
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Kebijakan Privasi',
            subtitle: 'Cara kami mengelola data Anda',
            onTap: () => _showInfoDialog(
              context,
              'Kebijakan Privasi',
              'Data Anda disimpan secara aman menggunakan Firebase. '
                  'Kami hanya mengumpulkan data yang diperlukan untuk '
                  'menjalankan aplikasi. Data tidak akan dibagikan '
                  'ke pihak ketiga tanpa persetujuan Anda.',
            ),
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Daddies Padel Community',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Made with passion for padel',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const _SectionHeader({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right,
                  color: colorScheme.onSurface.withValues(alpha: 0.3))
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
