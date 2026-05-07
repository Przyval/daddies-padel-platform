import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/slot_model.dart';
import 'package:daddies_app/models/payment_model.dart';
import 'package:daddies_app/models/cashflow_model.dart';
import 'package:daddies_app/models/rating_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/core/errors/app_exceptions.dart';
import 'package:daddies_app/core/services/analytics_service.dart';
import 'package:daddies_app/core/services/notification_service.dart';
import 'package:daddies_app/models/notification_model.dart';
import 'package:daddies_app/core/resilience/rate_limiter.dart';
import 'package:daddies_app/core/resilience/bulkhead.dart';
import 'package:daddies_app/core/resilience/circuit_breaker.dart';

class SessionProvider extends ChangeNotifier {
  final DataService _dataService = DataService();
  AuthProvider _authProvider;
  final Uuid _uuid = const Uuid();

  bool _isBusy = false;
  String? _errorMessage;

  SessionProvider(this._authProvider);

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void updateAuth(AuthProvider auth) {
    _authProvider = auth;
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<SessionModel> get sessions {
    final allSessions = List<SessionModel>.from(_dataService.sessions);
    allSessions.sort((a, b) => b.date.compareTo(a.date));
    return allSessions;
  }

  List<SessionModel> get openSessions {
    return sessions.where((s) => s.status == SessionStatus.open).toList();
  }

  SessionModel? getSessionById(String id) {
    return _dataService.getSessionById(id);
  }

  List<SlotModel> getSlotsForSession(String sessionId) {
    return _dataService.getSlotsForSession(sessionId);
  }

  List<PaymentModel> getPaymentsForSession(String sessionId) {
    return _dataService.getPaymentsForSession(sessionId);
  }

  // ---------------------------------------------------------------------------
  // Session CRUD
  // ---------------------------------------------------------------------------

  Future<bool> createSession({
    required String title,
    required String venue,
    required DateTime date,
    required String timeStart,
    required String timeEnd,
    required int maxPlayers,
    required int pricePerPlayer,
    String? notes,
    int? courtNumber,
  }) async {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = SessionModel(
        id: _uuid.v4(),
        miminId: currentUser.id,
        miminName: currentUser.name,
        title: title,
        venue: venue,
        date: date,
        timeStart: timeStart,
        timeEnd: timeEnd,
        maxPlayers: maxPlayers,
        pricePerPlayer: pricePerPlayer,
        status: SessionStatus.open,
        createdAt: DateTime.now(),
        notes: notes,
        courtNumber: courtNumber,
      );

      await _dataService.addSession(session);

      NotificationService.instance.pushLocal(
        title: 'Sesi Baru Dibuat',
        body: '$title di $venue',
        type: NotificationType.sessionCreated,
        sessionId: session.id,
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membuat sesi. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSession(SessionModel updated) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dataService.updateSession(updated);
      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui sesi. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSessionStatus(
      String sessionId, SessionStatus newStatus) async {
    final session = _dataService.getSessionById(sessionId);
    if (session == null) return false;
    final currentUser = _authProvider.currentUser;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = session.copyWith(status: newStatus);
      await _dataService.updateSession(updated);

      // Create refund cashflow entries when cancelling a session
      if (newStatus == SessionStatus.cancelled && currentUser != null) {
        await _createRefundEntries(sessionId: sessionId, sessionTitle: session.title, recordedBy: currentUser.name);
      }

      final notifType = switch (newStatus) {
        SessionStatus.locked => NotificationType.sessionLocked,
        SessionStatus.completed => NotificationType.sessionCompleted,
        SessionStatus.cancelled => NotificationType.sessionCancelled,
        _ => null,
      };
      if (notifType != null) {
        NotificationService.instance.pushLocal(
          title: 'Status Sesi Diperbarui',
          body: '${session.title} — ${updated.statusLabel}',
          type: notifType,
          sessionId: sessionId,
        );
      }

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengupdate status sesi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelSessionWithReason(String sessionId, String reason) async {
    final session = _dataService.getSessionById(sessionId);
    if (session == null) return false;
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = session.copyWith(
        status: SessionStatus.cancelled,
        cancellationReason: reason,
      );
      await _dataService.updateSession(updated);

      // Create refund cashflow entries
      await _createRefundEntries(sessionId: sessionId, sessionTitle: session.title, recordedBy: currentUser.name);

      NotificationService.instance.pushLocal(
        title: 'Sesi Dibatalkan',
        body: '${session.title} dibatalkan: $reason',
        type: NotificationType.sessionCancelled,
        sessionId: sessionId,
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membatalkan sesi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> duplicateSession(SessionModel original) async {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = SessionModel(
        id: _uuid.v4(),
        miminId: currentUser.id,
        miminName: currentUser.name,
        title: original.title,
        venue: original.venue,
        date: _nextWeekSameDay(original.date),
        timeStart: original.timeStart,
        timeEnd: original.timeEnd,
        maxPlayers: original.maxPlayers,
        pricePerPlayer: original.pricePerPlayer,
        status: SessionStatus.open,
        createdAt: DateTime.now(),
        notes: original.notes,
        courtNumber: original.courtNumber,
      );

      await _dataService.addSession(session);

      NotificationService.instance.pushLocal(
        title: 'Sesi Baru Dibuat',
        body: '${session.title} di ${session.venue}',
        type: NotificationType.sessionCreated,
        sessionId: session.id,
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menduplikasi sesi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Slot management (join / leave)
  // ---------------------------------------------------------------------------

  Future<bool> joinSession(String sessionId) async {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    // Fail Fast: validate prerequisites before expensive operation
    if (!canUserJoin(sessionId)) return false;

    // Governor: rate-limit session actions to prevent abuse
    if (!AppRateLimits.sessionAction.tryAcquire()) {
      _errorMessage = 'Terlalu banyak percobaan. Tunggu sebentar.';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final sw = Stopwatch()..start();
    try {
      // Bulkhead: critical operations get dedicated capacity
      await AppBulkheads.critical.execute(() async {
        await _dataService.joinSessionAtomic(
          sessionId: sessionId,
          userId: currentUser.id,
          userName: currentUser.name,
          newSlotId: _uuid.v4(),
        );
      });
      AnalyticsService.instance.logBookingAttempt(
        success: true,
        latencyMs: sw.elapsedMilliseconds,
      );
      _isBusy = false;
      notifyListeners();
      return true;
    } on CircuitBreakerOpenException {
      _errorMessage = 'Server sedang bermasalah. Coba lagi dalam beberapa saat.';
      _isBusy = false;
      notifyListeners();
      return false;
    } on ConflictException catch (e) {
      AnalyticsService.instance.logBookingAttempt(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        errorType: 'conflict',
      );
      _errorMessage = e.message;
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      AnalyticsService.instance.logBookingAttempt(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        errorType: e.runtimeType.toString(),
      );
      _errorMessage = 'Gagal join sesi. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveSession(String sessionId) async {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Capture waitlist info before the atomic leave (for notification)
      final slotsBefore = _dataService.getSlotsForSession(sessionId);
      final userWasConfirmed = slotsBefore
          .where((s) => s.userId == currentUser.id)
          .any((s) =>
              s.status == SlotStatus.confirmed ||
              s.status == SlotStatus.paid ||
              s.status == SlotStatus.locked);
      final firstWaitlist = slotsBefore
          .where((s) => s.status == SlotStatus.waitlist)
          .toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      final promotedName =
          (userWasConfirmed && firstWaitlist.isNotEmpty)
              ? firstWaitlist.first.userName
              : null;

      await _dataService.leaveSessionAtomic(
        sessionId: sessionId,
        userId: currentUser.id,
      );

      // Notify if a waitlist member was promoted (handled atomically above)
      if (promotedName != null) {
        NotificationService.instance.pushLocal(
          title: 'Slot Terbuka!',
          body: '$promotedName dipromosikan dari waitlist ke sesi',
          type: NotificationType.waitlistPromoted,
          sessionId: sessionId,
        );
      }

      _isBusy = false;
      notifyListeners();
      return true;
    } on ConflictException catch (e) {
      _errorMessage = e.message;
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal keluar dari sesi. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Payment verification
  // ---------------------------------------------------------------------------

  Future<bool> verifyPayment(String paymentId) async {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    // Fail Fast: validate payment exists before expensive operation
    final payment = _dataService.getPaymentById(paymentId);
    if (payment == null) return false;

    // Fail Fast: already verified? Don't hit Firestore.
    if (payment.status == PaymentStatus.verified) {
      _errorMessage = 'Pembayaran sudah diverifikasi.';
      notifyListeners();
      return false;
    }

    // Governor: rate-limit payment actions
    if (!AppRateLimits.paymentAction.tryAcquire()) {
      _errorMessage = 'Terlalu banyak percobaan. Tunggu sebentar.';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final sw = Stopwatch()..start();
    try {
      final session = _dataService.getSessionById(payment.sessionId);
      final cashflow = CashFlowModel(
        id: _uuid.v4(),
        type: CashFlowType.income,
        category: 'Session Payment',
        amount: payment.amount,
        sessionId: payment.sessionId,
        description:
            'Pembayaran ${payment.userName} untuk sesi ${session?.title ?? payment.sessionId}',
        recordedBy: currentUser.name,
        createdAt: DateTime.now(),
      );

      // Bulkhead: critical operation
      await AppBulkheads.critical.execute(() async {
        await _dataService.verifyPaymentAtomic(
          paymentId: paymentId,
          verifierId: currentUser.id,
          cashflowEntry: cashflow,
        );
      });

      AnalyticsService.instance.logPaymentAttempt(
        success: true,
        latencyMs: sw.elapsedMilliseconds,
      );

      NotificationService.instance.pushLocal(
        title: 'Pembayaran Terverifikasi',
        body: 'Pembayaran ${payment.userName} sebesar Rp ${payment.amount} telah diverifikasi',
        type: NotificationType.paymentVerified,
        sessionId: payment.sessionId,
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } on CircuitBreakerOpenException {
      _errorMessage = 'Server sedang bermasalah. Coba lagi dalam beberapa saat.';
      _isBusy = false;
      notifyListeners();
      return false;
    } on ConflictException catch (e) {
      AnalyticsService.instance.logPaymentAttempt(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        errorType: 'conflict',
      );
      _errorMessage = e.message;
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      AnalyticsService.instance.logPaymentAttempt(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        errorType: e.runtimeType.toString(),
      );
      _errorMessage = 'Gagal verifikasi pembayaran. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectPayment(String paymentId) async {
    final payment = _dataService.getPaymentById(paymentId);
    if (payment == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedPayment =
          payment.copyWith(status: PaymentStatus.rejected);
      await _dataService.updatePayment(updatedPayment);

      NotificationService.instance.pushLocal(
        title: 'Pembayaran Ditolak',
        body: 'Pembayaran ${payment.userName} ditolak. Silakan upload ulang.',
        type: NotificationType.paymentRejected,
        sessionId: payment.sessionId,
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menolak pembayaran.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Payment upload
  // ---------------------------------------------------------------------------

  Future<bool> uploadPaymentProof({
    required String sessionId,
    required String userId,
    required String userName,
    required int amount,
    required String proofImagePath,
  }) async {
    // Guard: block upload on locked/completed/cancelled sessions
    final session = _dataService.getSessionById(sessionId);
    if (session != null &&
        (session.status == SessionStatus.locked ||
         session.status == SessionStatus.completed ||
         session.status == SessionStatus.cancelled)) {
      _errorMessage = 'Sesi sudah ${session.statusLabel.toLowerCase()}, tidak bisa upload pembayaran.';
      notifyListeners();
      return false;
    }

    final slots = _dataService.getSlotsForSession(sessionId);
    final userSlot = slots.where((s) => s.userId == userId).toList();
    if (userSlot.isEmpty) return false;

    // Guard: prevent duplicate payment submission
    final existingPayment = _dataService.getPaymentForSlot(userSlot.first.id);
    if (existingPayment != null) {
      _errorMessage = 'Kamu sudah mengirim bukti pembayaran untuk sesi ini.';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payment = PaymentModel(
        id: _uuid.v4(),
        slotId: userSlot.first.id,
        sessionId: sessionId,
        userId: userId,
        userName: userName,
        amount: amount,
        proofImagePath: proofImagePath,
        status: PaymentStatus.pending,
        verifiedBy: null,
        verifiedAt: null,
        createdAt: DateTime.now(),
      );

      await _dataService.addPayment(payment);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengirim bukti pembayaran. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  int getConfirmedCount(String sessionId) {
    final slots = _dataService.getSlotsForSession(sessionId);
    return slots
        .where((s) =>
            s.status == SlotStatus.confirmed ||
            s.status == SlotStatus.paid ||
            s.status == SlotStatus.locked)
        .length;
  }

  int getPaidCount(String sessionId) {
    final slots = _dataService.getSlotsForSession(sessionId);
    return slots
        .where(
            (s) => s.status == SlotStatus.paid || s.status == SlotStatus.locked)
        .length;
  }

  bool canUserJoin(String sessionId) {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    final session = _dataService.getSessionById(sessionId);
    if (session == null) return false;

    if (session.status == SessionStatus.locked ||
        session.status == SessionStatus.completed ||
        session.status == SessionStatus.cancelled) {
      return false;
    }

    final slots = _dataService.getSlotsForSession(sessionId);
    return !slots.any((s) => s.userId == currentUser.id);
  }

  // ---------------------------------------------------------------------------
  // Refund helper
  // ---------------------------------------------------------------------------

  Future<void> _createRefundEntries({
    required String sessionId,
    required String sessionTitle,
    required String recordedBy,
  }) async {
    final payments = _dataService.getPaymentsForSession(sessionId);
    final verifiedPayments = payments.where((p) => p.status == PaymentStatus.verified);
    for (final payment in verifiedPayments) {
      final refundEntry = CashFlowModel(
        id: _uuid.v4(),
        type: CashFlowType.expense,
        category: 'Refund',
        amount: payment.amount,
        sessionId: sessionId,
        description: 'Refund ${payment.userName} — sesi "$sessionTitle" dibatalkan',
        recordedBy: recordedBy,
        createdAt: DateTime.now(),
      );
      await _dataService.addCashFlow(refundEntry);
    }
  }

  // ---------------------------------------------------------------------------
  // Rating
  // ---------------------------------------------------------------------------

  List<RatingModel> getRatingsForSession(String sessionId) {
    return _dataService.getRatingsForSession(sessionId);
  }

  bool hasUserRatedSession(String sessionId) {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;
    final ratings = _dataService.getRatingsForSession(sessionId);
    return ratings.any((r) => r.fromUserId == currentUser.id);
  }

  Future<bool> submitRatings({
    required String sessionId,
    required Map<String, int> playerRatings, // userId -> rating (1-5)
  }) async {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      for (final entry in playerRatings.entries) {
        final user = _dataService.getUserById(entry.key);
        final rating = RatingModel(
          id: _uuid.v4(),
          sessionId: sessionId,
          fromUserId: currentUser.id,
          toUserId: entry.key,
          toUserName: user?.name ?? 'Unknown',
          rating: entry.value,
          createdAt: DateTime.now(),
        );
        await _dataService.addRating(rating);
      }

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengirim rating.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session Photos
  // ---------------------------------------------------------------------------

  List<String> getPhotosForSession(String sessionId) {
    return _dataService.getPhotosForSession(sessionId);
  }

  Future<bool> addPhotoToSession(String sessionId, String photoPath) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _dataService.addPhotoToSession(sessionId, photoPath);
      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan foto.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removePhotoFromSession(String sessionId, String photoPath) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _dataService.removePhotoFromSession(sessionId, photoPath);
      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus foto.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session Invites
  // ---------------------------------------------------------------------------

  Future<bool> invitePlayers(String sessionId, List<String> userIds) async {
    final session = _dataService.getSessionById(sessionId);
    if (session == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Use arrayUnion for atomic invite merge — prevents last-write-wins
      // race when two concurrent invite calls happen.
      await _dataService.atomicArrayUnion(
        collection: 'sessions',
        docId: sessionId,
        field: 'invitedPlayerIds',
        values: userIds,
      );

      // Send notification to each invited player
      for (final _ in userIds) {
        NotificationService.instance.pushLocal(
          title: 'Undangan Sesi',
          body: 'Kamu diundang ke sesi "${session.title}" di ${session.venue}',
          type: NotificationType.sessionInvite,
          sessionId: sessionId,
        );
      }

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengirim undangan.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  DateTime _nextWeekSameDay(DateTime date) {
    final now = DateTime.now();
    var next = date.add(const Duration(days: 7));
    while (next.isBefore(now)) {
      next = next.add(const Duration(days: 7));
    }
    return next;
  }
}
