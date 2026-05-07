import 'package:flutter/material.dart';

import 'package:daddies_app/core/services/connectivity_service.dart';
import 'package:daddies_app/core/theme/app_colors.dart';

/// A persistent banner shown at the top when the device is offline.
/// Uses [ConnectivityService.isOnline] to toggle visibility.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, online, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: online
              ? const SizedBox.shrink()
              : Container(
                  key: const ValueKey('offline'),
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.clayRed,
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: AppColors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Tidak ada koneksi internet',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
