import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';

/// A guest-to-member conversion widget that gates interactive actions behind
/// authentication. When an authenticated user taps, [onAuthenticated] fires
/// immediately. When a guest taps, a bottom sheet encouraging sign-up is shown.
class AuthGate extends StatelessWidget {
  final Widget child;
  final VoidCallback onAuthenticated;
  final String? message;

  const AuthGate({
    super.key,
    required this.child,
    required this.onAuthenticated,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final auth = context.read<AuthProvider>();
        if (auth.isLoggedIn) {
          onAuthenticated();
        } else {
          showAuthSheet(context, message: message);
        }
      },
      child: child,
    );
  }

  /// Shows the authentication encouragement bottom sheet directly.
  /// Useful when you need to trigger the sheet from a callback rather than
  /// wrapping a widget.
  static void showAuthSheet(BuildContext context, {String? message}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthBottomSheet(message: message),
    );
  }
}

class _AuthBottomSheet extends StatelessWidget {
  final String? message;

  const _AuthBottomSheet({this.message});

  static const _benefits = [
    'Kartu anggota digital (KTA)',
    'Ikut sesi padel mingguan',
    'Dapatkan Daddies Chips & rewards',
    'Diskon eksklusif dari partner',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.sagePaper,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Gabung Daddies Padel',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.forestInk,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle / custom message
            Text(
              message ?? 'Gabung komunitas untuk menikmati fitur ini',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mossAccent,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Benefits list
            ...List.generate(_benefits.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.mossAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.mossAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _benefits[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.deepCharcoal,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Primary CTA — "Gabung Sekarang"
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestInk,
                  foregroundColor: AppColors.agedLinen,
                  shape: const StadiumBorder(),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Gabung Sekarang'),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary CTA — "Nanti Saja"
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mossAccent,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Nanti Saja'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
