import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/widgets/google_logo_painter.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';

/// Onboarding Page 3 — Inline login (no separate login screen needed).
class OnboardingLoginPage extends StatefulWidget {
  const OnboardingLoginPage({super.key});

  @override
  State<OnboardingLoginPage> createState() => _OnboardingLoginPageState();
}

class _OnboardingLoginPageState extends State<OnboardingLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showPhoneLogin = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signInWithGoogle();
      if (!mounted) return;
      if (success) {
        await _markOnboardingDone();
        if (!mounted) return;
        context.go(authProvider.isFirstLogin
            ? AppRoutes.welcomeFlow
            : AppRoutes.home);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signInWithFacebook();
      if (!mounted) return;
      if (success) {
        await _markOnboardingDone();
        if (!mounted) return;
        context.go(authProvider.isFirstLogin
            ? AppRoutes.welcomeFlow
            : AppRoutes.home);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePhoneLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        _phoneController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (success) {
        await _markOnboardingDone();
        if (!mounted) return;
        context.go(AppRoutes.home);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _browseAsGuest() async {
    await _markOnboardingDone();
    if (!mounted) return;
    context.go(AppRoutes.explore);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),

          // Header
          Text(
            'Siap Main?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.forestInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gabung komunitas dalam 1 ketukan',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // Google Sign-In
          _SocialButton(
            onTap: _isLoading ? null : _handleGoogleSignIn,
            icon: SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: GoogleLogoPainter()),
            ),
            label: 'Lanjutkan dengan Google',
          ),

          const SizedBox(height: 12),

          // Facebook Sign-In
          _SocialButton(
            onTap: _isLoading ? null : _handleFacebookSignIn,
            icon: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFF1877F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'f',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            label: 'Lanjutkan dengan Facebook',
          ),

          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              Expanded(
                  child: Divider(color: AppColors.divider, thickness: 0.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('atau',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textTertiary)),
              ),
              Expanded(
                  child: Divider(color: AppColors.divider, thickness: 0.5)),
            ],
          ),

          const SizedBox(height: 16),

          // Phone login toggle
          if (!_showPhoneLogin)
            _SocialButton(
              onTap: () => setState(() => _showPhoneLogin = true),
              icon: Icon(Icons.phone_outlined,
                  size: 20, color: AppColors.forestInk),
              label: 'Masuk dengan No. HP',
            ),

          // Phone login form
          if (_showPhoneLogin) _buildPhoneForm(),

          const SizedBox(height: 24),

          // Browse as guest
          TextButton(
            onPressed: _isLoading ? null : _browseAsGuest,
            child: Text(
              'Lewati, lihat-lihat dulu',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.mossAccent,
              ),
            ),
          ),

          // Debug demo accounts
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _buildDemoAccounts(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Phone field
          TextFormField(
            controller: _phoneController,
            focusNode: FocusNode(),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.phone_outlined, color: AppColors.mossAccent),
              hintText: 'Nomor HP (mis. 08119990001)',
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (v) =>
                (v == null || v.length < 4) ? 'Nomor HP wajib diisi' : null,
          ),
          const SizedBox(height: 12),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.lock_outline, color: AppColors.mossAccent),
              hintText: 'Password',
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textTertiary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
          ),
          const SizedBox(height: 16),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePhoneLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestInk,
                foregroundColor: AppColors.onPrimary,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoAccounts() {
    final accounts = [
      ('08119990001', 'Admin', Icons.shield_outlined),
      ('08119990002', 'Mimin', Icons.manage_accounts_outlined),
      ('08119990004', 'Bendahara', Icons.account_balance_wallet_outlined),
      ('08129990005', 'Member', Icons.person_outline),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demo Accounts (password: daddies)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accounts.map((a) {
              return GestureDetector(
                onTap: () {
                  _phoneController.text = a.$1;
                  _passwordController.text = 'daddies';
                  if (!_showPhoneLogin) {
                    setState(() => _showPhoneLogin = true);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(a.$3, size: 14, color: AppColors.forestInk),
                      const SizedBox(width: 4),
                      Text(
                        a.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forestInk,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget icon;
  final String label;

  const _SocialButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceContainerLow,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
