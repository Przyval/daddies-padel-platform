import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:daddies_app/models/redemption_model.dart';
import 'package:daddies_app/models/partner_model.dart';
import 'package:daddies_app/models/chips_transaction_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/features/chips/providers/chips_provider.dart';

class RedemptionProvider extends ChangeNotifier {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();

  bool _isBusy = false;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Returns all non-deleted redemptions for the given user, sorted newest first.
  List<RedemptionModel> getRedemptionsForUser(String userId) {
    final all = _dataService.redemptions
        .where((r) => r.userId == userId && !r.isDeleted)
        .toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// Returns only active (pending and not expired) redemptions for the given user.
  List<RedemptionModel> getActiveRedemptions(String userId) {
    final now = DateTime.now();
    return getRedemptionsForUser(userId)
        .where((r) =>
            r.status == RedemptionStatus.pending &&
            r.expiresAt.isAfter(now))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Create Redemption
  // ---------------------------------------------------------------------------

  /// Creates a new redemption for a partner discount.
  ///
  /// Validates the user has enough chips, deducts chips via [chipsProvider],
  /// and creates a [RedemptionModel] with a 30-day expiry window.
  Future<bool> createRedemption({
    required String userId,
    required String userName,
    required PartnerModel partner,
    required ChipsProvider chipsProvider,
  }) async {
    final chipsPrice = partner.chipsPrice ?? 0;
    if (chipsPrice <= 0) {
      _errorMessage = 'Partner ini belum memiliki harga chips.';
      notifyListeners();
      return false;
    }

    final balance = chipsProvider.getBalance(userId);
    if (balance < chipsPrice) {
      _errorMessage = 'Chips tidak cukup. Butuh $chipsPrice, saldo kamu $balance.';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Deduct chips
      final chipsOk = await chipsProvider.awardChips(
        userId: userId,
        userName: userName,
        amount: -chipsPrice,
        source: ChipsSource.redemption,
        description: 'Tukar chips: ${partner.discountDescription}',
      );

      if (!chipsOk) {
        _errorMessage = 'Gagal mengurangi chips. Coba lagi.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      final now = DateTime.now();
      final redemption = RedemptionModel(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        partnerId: partner.id,
        partnerName: partner.name,
        chipsSpent: chipsPrice,
        discountDescription: partner.discountDescription,
        status: RedemptionStatus.pending,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      );

      await _dataService.addRedemption(redemption);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membuat redemption. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Mark Used
  // ---------------------------------------------------------------------------

  /// Marks a pending redemption as used by a verifier.
  Future<bool> markUsed(String redemptionId, String verifierId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final redemption = _dataService.redemptions
          .where((r) => r.id == redemptionId)
          .firstOrNull;

      if (redemption == null) {
        _errorMessage = 'Redemption tidak ditemukan.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      if (redemption.status != RedemptionStatus.pending) {
        _errorMessage = 'Redemption sudah ${redemption.statusLabel.toLowerCase()}.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      final updated = redemption.copyWith(
        status: RedemptionStatus.used,
        usedAt: DateTime.now(),
        verifiedBy: verifierId,
      );

      await _dataService.updateRedemption(updated);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memverifikasi redemption. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel Redemption
  // ---------------------------------------------------------------------------

  /// Cancels a pending redemption and refunds the chips back to the user.
  Future<bool> cancelRedemption(
    String redemptionId,
    ChipsProvider chipsProvider,
  ) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final redemption = _dataService.redemptions
          .where((r) => r.id == redemptionId)
          .firstOrNull;

      if (redemption == null) {
        _errorMessage = 'Redemption tidak ditemukan.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      if (redemption.status != RedemptionStatus.pending) {
        _errorMessage = 'Hanya redemption aktif yang bisa dibatalkan.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      // Refund chips
      final refundOk = await chipsProvider.awardChips(
        userId: redemption.userId,
        userName: redemption.userName,
        amount: redemption.chipsSpent,
        source: ChipsSource.redemption,
        description: 'Refund: ${redemption.discountDescription}',
      );

      if (!refundOk) {
        _errorMessage = 'Gagal mengembalikan chips. Coba lagi.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      final updated = redemption.copyWith(
        status: RedemptionStatus.cancelled,
      );

      await _dataService.updateRedemption(updated);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membatalkan redemption. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Check Expired Redemptions
  // ---------------------------------------------------------------------------

  /// Scans all pending redemptions and marks those past their expiry as expired.
  void checkExpiredRedemptions() {
    final now = DateTime.now();
    final pendingExpired = _dataService.redemptions
        .where((r) =>
            r.status == RedemptionStatus.pending &&
            !r.isDeleted &&
            r.expiresAt.isBefore(now))
        .toList();

    for (final redemption in pendingExpired) {
      final updated = redemption.copyWith(
        status: RedemptionStatus.expired,
      );
      _dataService.updateRedemption(updated);
    }

    if (pendingExpired.isNotEmpty) {
      notifyListeners();
    }
  }
}
