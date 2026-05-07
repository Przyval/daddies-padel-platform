import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/services/storage_service.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/widgets/success_overlay.dart';
import 'package:daddies_app/core/utils/haptic_helper.dart';

class PaymentUploadScreen extends StatefulWidget {
  final SessionModel session;

  const PaymentUploadScreen({super.key, required this.session});

  @override
  State<PaymentUploadScreen> createState() => _PaymentUploadScreenState();
}

class _PaymentUploadScreenState extends State<PaymentUploadScreen> {
  File? _selectedImage;
  bool _isUploading = false;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 80);
    if (picked != null) {
      final file = File(picked.path);
      final sizeInBytes = file.lengthSync();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      if (sizeInMB > 5) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            'Ukuran file maksimal 5 MB. File ini ${sizeInMB.toStringAsFixed(1)} MB.',
          );
        }
        return;
      }
      setState(() => _selectedImage = file);
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedImage == null) {
      SnackbarHelper.showError(context, 'Pilih bukti transfer terlebih dahulu');
      return;
    }

    setState(() => _isUploading = true);

    final auth = context.read<AuthProvider>();
    final sessionProv = context.read<SessionProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    final userId = currentUser.id;

    try {
      // Upload image to Firebase Storage
      final downloadUrl = await StorageService.instance.uploadPaymentProof(
        file: _selectedImage!,
        sessionId: widget.session.id,
        userId: userId,
      );

      if (!mounted) return;

      // Save payment record with the download URL
      final success = await sessionProv.uploadPaymentProof(
        sessionId: widget.session.id,
        userId: userId,
        userName: currentUser.name,
        amount: widget.session.pricePerPlayer,
        proofImagePath: downloadUrl,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (success) {
        HapticHelper.success();
        SuccessOverlay.show(context, message: 'Bukti transfer berhasil diupload!');
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop(true);
        return;
      } else {
        SnackbarHelper.showError(context, sessionProv.errorMessage ?? 'Gagal menyimpan bukti transfer');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      SnackbarHelper.showError(context, 'Gagal mengupload gambar. Periksa koneksi internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upload Bukti Transfer'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Payment info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Sesi', value: widget.session.title),
                _InfoRow(label: 'Venue', value: widget.session.venue),
                _InfoRow(label: 'Tanggal', value: DateFormat('d MMMM yyyy', 'id_ID').format(widget.session.date)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nominal Transfer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      rupiah.format(widget.session.pricePerPlayer),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bank info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.forestInk.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transfer ke:',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'BCA — 1234567890',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepCharcoal,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: '1234567890'));
                        HapticHelper.light();
                        SnackbarHelper.showSuccess(context, 'Nomor rekening disalin');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.forestInk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.copy_outlined,
                          size: 18,
                          color: AppColors.forestInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'a.n. Daddies Padel Community',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Image picker
          const Text(
            'Bukti Transfer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
            ),
          ),
          const SizedBox(height: 10),

          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                _selectedImage!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => setState(() => _selectedImage = null),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Hapus & pilih ulang'),
              style: TextButton.styleFrom(foregroundColor: AppColors.clayRed),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Kamera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeri',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submitPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestInk,
                foregroundColor: AppColors.textOnPrimary,
                shape: const StadiumBorder(),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    )
                  : const Text(
                      'Kirim Bukti Transfer',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.deepCharcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.mossAccent),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
