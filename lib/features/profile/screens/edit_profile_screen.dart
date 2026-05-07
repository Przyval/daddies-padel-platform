import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/validators.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/widgets/loading_overlay.dart';
import 'package:daddies_app/core/widgets/success_overlay.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _bioController;
  bool _isSaving = false;

  File? _avatarFile;
  String? _existingAvatarUrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _existingAvatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.forestInk),
                title: const Text('Ambil Foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.forestInk),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      imageQuality: 85,
    );

    if (picked != null) {
      final file = File(picked.path);
      final sizeInMB = file.lengthSync() / (1024 * 1024);
      if (sizeInMB > 3) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Ukuran foto maksimal 3 MB');
        }
        return;
      }
      setState(() => _avatarFile = file);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final nickname = _nicknameController.text.trim();
    final bio = _bioController.text.trim();

    String? avatarUrl;

    // Upload new avatar if selected
    if (_avatarFile != null) {
      try {
        avatarUrl = await StorageService.instance.uploadAvatar(
          file: _avatarFile!,
          userId: auth.currentUser?.id ?? '',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        SnackbarHelper.showError(context, 'Gagal upload foto. Coba lagi.');
        return;
      }
    }

    if (!mounted) return;

    final success = await auth.updateProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      nickname: nickname.isEmpty ? null : nickname,
      bio: bio.isEmpty ? null : bio,
      avatarUrl: avatarUrl,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      SuccessOverlay.show(context, message: 'Profil berhasil diperbarui');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Gagal memperbarui profil'),
          backgroundColor: AppColors.clayRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final initials = user != null && user.name.isNotEmpty
        ? user.name[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: LoadingOverlay(
        isLoading: _isSaving,
        message: 'Menyimpan...',
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),

              // Avatar
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.forestInk.withValues(alpha: 0.1),
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!)
                            : (_existingAvatarUrl != null
                                ? CachedNetworkImageProvider(_existingAvatarUrl!)
                                : null) as ImageProvider?,
                        child: (_avatarFile == null && _existingAvatarUrl == null)
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.forestInk,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.forestInk,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: AppColors.agedLinen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Ketuk untuk ganti foto',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppColors.mossAccent),
                ),
                textCapitalization: TextCapitalization.words,
                validator: Validators.name,
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon',
                  prefixIcon:
                      Icon(Icons.phone_outlined, color: AppColors.mossAccent),
                ),
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),
              const SizedBox(height: 16),

              // Nickname
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Nickname (opsional)',
                  hintText: 'Nama panggilan di lapangan',
                  prefixIcon:
                      Icon(Icons.badge_outlined, color: AppColors.mossAccent),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio (opsional)',
                  hintText: 'Ceritakan tentang gaya bermainmu...',
                  prefixIcon:
                      Icon(Icons.edit_note_outlined, color: AppColors.mossAccent),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestInk,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Simpan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
