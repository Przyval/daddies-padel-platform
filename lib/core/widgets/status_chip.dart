import 'package:flutter/material.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/slot_model.dart';
import 'package:daddies_app/models/payment_model.dart';

class SessionStatusChip extends StatelessWidget {
  final SessionStatus status;

  const SessionStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, label) = switch (status) {
      SessionStatus.draft => (AppColors.textSecondary, AppColors.sagePaper, 'Draft'),
      SessionStatus.open => (AppColors.statusOpen, const Color(0xFFE8F5E9), 'Open'),
      SessionStatus.full => (AppColors.statusWaitlist, const Color(0xFFFFF8E1), 'Full'),
      SessionStatus.locked => (AppColors.statusLocked, const Color(0xFFE0E4E1), 'Locked'),
      SessionStatus.completed => (AppColors.statusCompleted, const Color(0xFFE8EDE7), 'Selesai'),
      SessionStatus.cancelled => (AppColors.statusCancelled, const Color(0xFFFBE9E7), 'Batal'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class SlotStatusChip extends StatelessWidget {
  final SlotStatus status;

  const SlotStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, label) = switch (status) {
      SlotStatus.registered => (AppColors.textSecondary, AppColors.sagePaper, 'Registered'),
      SlotStatus.waitlist => (AppColors.statusWaitlist, const Color(0xFFFFF8E1), 'Waitlist'),
      SlotStatus.confirmed => (AppColors.statusOpen, const Color(0xFFE8F5E9), 'Confirmed'),
      SlotStatus.paid => (AppColors.statusPaid, const Color(0xFFE3F2FD), 'Paid'),
      SlotStatus.locked => (AppColors.statusLocked, const Color(0xFFE0E4E1), 'Locked'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class PaymentStatusChip extends StatelessWidget {
  final PaymentStatus status;

  const PaymentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, label) = switch (status) {
      PaymentStatus.pending => (AppColors.statusWaitlist, const Color(0xFFFFF8E1), 'Menunggu'),
      PaymentStatus.verified => (AppColors.statusOpen, const Color(0xFFE8F5E9), 'Verified'),
      PaymentStatus.rejected => (AppColors.statusCancelled, const Color(0xFFFBE9E7), 'Ditolak'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
