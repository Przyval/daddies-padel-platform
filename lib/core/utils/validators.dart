/// Centralized input validators for forms across the app.
class Validators {
  Validators._();

  /// Phone number: starts with 08, 10-14 digits.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Masukkan nomor telepon';
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (!digits.startsWith('08')) return 'Nomor harus diawali 08';
    if (digits.length < 10) return 'Nomor terlalu pendek (min 10 digit)';
    if (digits.length > 14) return 'Nomor terlalu panjang (maks 14 digit)';
    return null;
  }

  /// Non-empty required field.
  static String? required(String? value, [String fieldName = 'Field ini']) {
    if (value == null || value.trim().isEmpty) return '$fieldName harus diisi';
    return null;
  }

  /// Price/amount: must be a positive integer.
  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) return 'Masukkan jumlah';
    final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    if (parsed == null || parsed <= 0) return 'Jumlah harus lebih dari 0';
    return null;
  }

  /// Max players: 2–20.
  static String? maxPlayers(String? value) {
    if (value == null || value.trim().isEmpty) return 'Masukkan jumlah pemain';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 2) return 'Minimal 2 pemain';
    if (parsed > 20) return 'Maksimal 20 pemain';
    return null;
  }

  /// Time format: HH:mm (24-hour).
  static String? timeFormat(String? value) {
    if (value == null || value.trim().isEmpty) return 'Masukkan waktu';
    final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    if (!regex.hasMatch(value.trim())) return 'Format: HH:mm (contoh: 19:00)';
    return null;
  }

  /// Person name: non-empty, 2+ characters.
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Masukkan nama';
    if (value.trim().length < 2) return 'Nama terlalu pendek';
    return null;
  }
}
