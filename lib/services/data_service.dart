import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/slot_model.dart';
import 'package:daddies_app/models/payment_model.dart';
import 'package:daddies_app/models/cashflow_model.dart';
import 'package:daddies_app/models/venue_model.dart';
import 'package:daddies_app/models/rating_model.dart';
import 'package:daddies_app/models/partner_model.dart';
import 'package:daddies_app/models/match_result_model.dart';
import 'package:daddies_app/models/chips_transaction_model.dart';
import 'package:daddies_app/models/award_model.dart';
import 'package:daddies_app/models/redemption_model.dart';
import 'package:daddies_app/models/referral_model.dart';
import 'package:daddies_app/services/firestore_service.dart';
import 'package:daddies_app/core/errors/app_exceptions.dart';
import 'package:daddies_app/core/services/analytics_service.dart';
import 'package:daddies_app/core/services/app_logger.dart';
import 'package:daddies_app/core/resilience/rate_limiter.dart';

/// DataService: local cache + Firestore sync.
///
/// Providers read synchronously from the local cache.
/// Mutations write to Firestore FIRST, then update local cache on success.
/// On init, data is loaded from Firestore into the local cache.
class DataService extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  DataService._internal();
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;

  final FirestoreService _fs = FirestoreService.instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? _lastError;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;

  /// Timestamp of last successful Firestore sync (null if never synced).
  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  // ---------------------------------------------------------------------------
  // Firestore stream subscriptions
  // ---------------------------------------------------------------------------
  StreamSubscription<List<SessionModel>>? _sessionsSub;
  StreamSubscription<List<SlotModel>>? _slotsSub;
  StreamSubscription<List<PaymentModel>>? _paymentsSub;
  StreamSubscription<List<CashFlowModel>>? _cashflowsSub;

  // ---------------------------------------------------------------------------
  // In-memory cache
  // ---------------------------------------------------------------------------
  final List<UserModel> _users = [];
  final List<SessionModel> _sessions = [];
  final List<SlotModel> _slots = [];
  final List<PaymentModel> _payments = [];
  final List<CashFlowModel> _cashflows = [];
  final List<VenueModel> _venues = [];
  final List<RatingModel> _ratings = [];
  final List<PartnerModel> _partners = [];
  final List<MatchResultModel> _matchResults = [];
  final List<ChipsTransactionModel> _chipsTransactions = [];
  final List<AwardModel> _awards = [];
  final List<RedemptionModel> _redemptions = [];
  final List<ReferralModel> _referrals = [];

  // ---------------------------------------------------------------------------
  // Public read-only accessors
  // ---------------------------------------------------------------------------
  List<UserModel> get users => List.unmodifiable(_users);
  List<SessionModel> get sessions => List.unmodifiable(_sessions);
  List<SlotModel> get slots => List.unmodifiable(_slots);
  List<PaymentModel> get payments => List.unmodifiable(_payments);
  List<CashFlowModel> get cashflows => List.unmodifiable(_cashflows);
  List<VenueModel> get venues => List.unmodifiable(_venues);
  List<RatingModel> get ratings => List.unmodifiable(_ratings);
  List<PartnerModel> get partners => List.unmodifiable(_partners);
  List<MatchResultModel> get matchResults => List.unmodifiable(_matchResults);
  List<ChipsTransactionModel> get chipsTransactions => List.unmodifiable(_chipsTransactions);
  List<AwardModel> get awards => List.unmodifiable(_awards);
  List<RedemptionModel> get redemptions => List.unmodifiable(_redemptions);
  List<ReferralModel> get referrals => List.unmodifiable(_referrals);

  // ---------------------------------------------------------------------------
  // Public data init (for guest browsing — no auth required)
  // ---------------------------------------------------------------------------
  bool _publicDataLoaded = false;

  /// Load only publicly-readable collections (sessions, venues, partners).
  /// Used for guest browsing before the user signs in.
  Future<void> initializePublicData() async {
    if (_publicDataLoaded) return;
    try {
      _sessions
        ..clear()
        ..addAll((await _fs.getSessions()).where((x) => !x.isDeleted));
      _venues
        ..clear()
        ..addAll((await _fs.getVenues()).where((x) => !x.isDeleted));
      _partners
        ..clear()
        ..addAll((await _fs.getPartners()).where((x) => !x.isDeleted));
      _users
        ..clear()
        ..addAll((await _fs.getUsers()).where((x) => !x.isDeleted));
      _publicDataLoaded = true;
      notifyListeners();
    } catch (e) {
      AppLogger.w('DataService', 'Public data init failed', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization: load from Firestore (or seed if empty)
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_initialized) return;

    final trace = FirebasePerformance.instance.newTrace('data_service_init');
    await trace.start();
    final sw = Stopwatch()..start();

    try {
      // Timeout protects against Firestore hanging when offline
      await _loadFromFirestore().timeout(const Duration(seconds: 10));

      // If Firestore returned no users, fall back to local seed
      if (_users.isEmpty) {
        AppLogger.w('DataService', 'Firestore returned 0 users — seeding locally');
        _seedLocalOnly();
      }

      _initialized = true;
      _lastError = null;
      _lastSyncedAt = DateTime.now();

      // Migration: ensure confirmedCount field exists on all session docs
      try {
        await _fs.syncConfirmedCounts().timeout(const Duration(seconds: 5));
      } catch (e) {
        AppLogger.w('DataService', 'syncConfirmedCounts failed', error: e);
      }

      _listenToStreams();

      trace.putAttribute('success', 'true');
      AnalyticsService.instance.logDataLoad(
        success: true,
        latencyMs: sw.elapsedMilliseconds,
        userCount: _users.length,
        sessionCount: _sessions.length,
      );

      AppLogger.i('DataService', 'Loaded: ${_users.length} users, '
          '${_sessions.length} sessions, ${_slots.length} slots, '
          '${_payments.length} payments, ${_cashflows.length} cashflows');
    } catch (e) {
      trace.putAttribute('success', 'false');
      AnalyticsService.instance.logDataLoad(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
      );

      AppLogger.e('DataService', 'Initialize failed — falling back to seed', error: e);
      _seedLocalOnly();
      _initialized = true;
      _lastError = 'Tidak bisa terhubung ke server. Menggunakan data lokal.';
    }

    await trace.stop();
    notifyListeners();
  }

  /// Loads all data from Firestore into local cache.
  Future<void> _loadFromFirestore() async {
    await _fs.seedIfEmpty();

    _users
      ..clear()
      ..addAll((await _fs.getUsers()).where((x) => !x.isDeleted));
    _sessions
      ..clear()
      ..addAll((await _fs.getSessions()).where((x) => !x.isDeleted));
    _slots
      ..clear()
      ..addAll((await _fs.getAllSlots()).where((x) => !x.isDeleted));
    _payments
      ..clear()
      ..addAll((await _fs.getAllPayments()).where((x) => !x.isDeleted));
    _cashflows
      ..clear()
      ..addAll((await _fs.getCashFlows()).where((x) => !x.isDeleted));
    _venues
      ..clear()
      ..addAll((await _fs.getVenues()).where((x) => !x.isDeleted));
    _ratings
      ..clear()
      ..addAll(await _fs.getRatings());
    _partners
      ..clear()
      ..addAll((await _fs.getPartners()).where((x) => !x.isDeleted));
    _matchResults
      ..clear()
      ..addAll((await _fs.getMatchResults()).where((x) => !x.isDeleted));
    _chipsTransactions
      ..clear()
      ..addAll((await _fs.getChipsTransactions()).where((x) => !x.isDeleted));
    _awards
      ..clear()
      ..addAll((await _fs.getAwards()).where((x) => !x.isDeleted));
    _redemptions
      ..clear()
      ..addAll((await _fs.getRedemptions()).where((x) => !x.isDeleted));
    _referrals
      ..clear()
      ..addAll((await _fs.getReferrals()).where((x) => !x.isDeleted));

    // Safety net: if Firestore has users but critical data is missing,
    // clear all and use local seed instead
    if (_users.isNotEmpty && _slots.isEmpty) {
      AppLogger.w('DataService', 'Firestore has users but no slots — falling back to local seed');
      _users.clear();
      _sessions.clear();
      _payments.clear();
      _cashflows.clear();
      _venues.clear();
      _ratings.clear();
      _partners.clear();
      _matchResults.clear();
      _chipsTransactions.clear();
      _awards.clear();
      _redemptions.clear();
      _referrals.clear();
      _seedLocalOnly();
    }
  }

  /// Refresh data from Firestore.
  ///
  /// Rate-limited to prevent excessive refreshes (Release It! — Governor).
  Future<void> refresh() async {
    if (_isRefreshing) return;

    // Governor: prevent refresh spam
    if (!AppRateLimits.dataRefresh.tryAcquire()) {
      AppLogger.w('DataService', 'Refresh rate-limited — too many recent refreshes');
      _lastError = 'Tunggu sebentar sebelum refresh lagi.';
      notifyListeners();
      return;
    }

    _isRefreshing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _loadFromFirestore().timeout(const Duration(seconds: 10));
      _lastError = null;
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      AppLogger.e('DataService', 'Refresh failed', error: e);
      _lastError = 'Gagal memuat data. Periksa koneksi internet.';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Subscribe to Firestore real-time streams. Called once after initial load.
  void _listenToStreams() {
    _cancelStreams();

    _sessionsSub = _fs.sessionsStream().listen((data) {
      _sessions
        ..clear()
        ..addAll(data.where((x) => !x.isDeleted));
      notifyListeners();
    }, onError: (e) {
      AppLogger.w('DataService', 'Sessions stream error', error: e);
      _lastError = 'Koneksi data terputus. Tarik ke bawah untuk refresh.';
      notifyListeners();
    });

    _slotsSub = _fs.allSlotsStream().listen((data) {
      _slots
        ..clear()
        ..addAll(data.where((x) => !x.isDeleted));
      notifyListeners();
    }, onError: (e) {
      AppLogger.w('DataService', 'Slots stream error', error: e);
      _lastError = 'Koneksi data terputus. Tarik ke bawah untuk refresh.';
      notifyListeners();
    });

    _paymentsSub = _fs.allPaymentsStream().listen((data) {
      _payments
        ..clear()
        ..addAll(data.where((x) => !x.isDeleted));
      notifyListeners();
    }, onError: (e) {
      AppLogger.w('DataService', 'Payments stream error', error: e);
      _lastError = 'Koneksi data terputus. Tarik ke bawah untuk refresh.';
      notifyListeners();
    });

    _cashflowsSub = _fs.cashFlowsStream().listen((data) {
      _cashflows
        ..clear()
        ..addAll(data.where((x) => !x.isDeleted));
      notifyListeners();
    }, onError: (e) {
      AppLogger.w('DataService', 'Cashflows stream error', error: e);
      _lastError = 'Koneksi data terputus. Tarik ke bawah untuk refresh.';
      notifyListeners();
    });
  }

  void _cancelStreams() {
    _sessionsSub?.cancel();
    _slotsSub?.cancel();
    _paymentsSub?.cancel();
    _cashflowsSub?.cancel();
    _sessionsSub = null;
    _slotsSub = null;
    _paymentsSub = null;
    _cashflowsSub = null;
  }

  /// Clear all cached data (used on logout).
  void clearCache() {
    _cancelStreams();
    _users.clear();
    _sessions.clear();
    _slots.clear();
    _payments.clear();
    _cashflows.clear();
    _venues.clear();
    _ratings.clear();
    _chipsTransactions.clear();
    _awards.clear();
    _redemptions.clear();
    _referrals.clear();
    _initialized = false;
    _lastError = null;
    notifyListeners();
  }

  // ===========================================================================
  // USER methods
  // ===========================================================================
  UserModel? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  UserModel? getUserByPhone(String phone) {
    try {
      return _users.firstWhere((u) => u.phone == phone);
    } catch (_) {
      return null;
    }
  }

  List<UserModel> getUsersByRole(UserRole role) {
    return _users.where((u) => u.role == role).toList();
  }

  Future<void> addUser(UserModel user) async {
    try {
      await _fs.setUser(user);
      _users.add(user);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menambah user.', e);
    }
  }

  Future<void> updateUser(UserModel user) async {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index == -1) return;

    try {
      await _fs.updateUser(user);
      _users[index] = user;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mengupdate user.', e);
    }
  }

  Future<void> removeUser(String userId) async {
    try {
      await _fs.removeUser(userId);
      _users.removeWhere((u) => u.id == userId);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus user.', e);
    }
  }

  // ===========================================================================
  // VENUE methods
  // ===========================================================================
  VenueModel? getVenueById(String id) {
    try {
      return _venues.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  VenueModel? getVenueByName(String name) {
    try {
      return _venues.firstWhere(
        (v) => v.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> addVenue(VenueModel venue) async {
    try {
      await _fs.setVenue(venue);
      _venues.add(venue);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menambah venue.', e);
    }
  }

  Future<void> updateVenue(VenueModel venue) async {
    final index = _venues.indexWhere((v) => v.id == venue.id);
    if (index == -1) return;

    try {
      await _fs.updateVenue(venue);
      _venues[index] = venue;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mengupdate venue.', e);
    }
  }

  Future<void> deleteVenue(String venueId) async {
    try {
      await _fs.deleteVenue(venueId);
      _venues.removeWhere((v) => v.id == venueId);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus venue.', e);
    }
  }

  // ===========================================================================
  // RATING methods
  // ===========================================================================
  List<RatingModel> getRatingsForSession(String sessionId) {
    return _ratings.where((r) => r.sessionId == sessionId).toList();
  }

  List<RatingModel> getRatingsForUser(String userId) {
    return _ratings.where((r) => r.toUserId == userId).toList();
  }

  List<RatingModel> getRatingsByUser(String userId) {
    return _ratings.where((r) => r.fromUserId == userId).toList();
  }

  double getAverageRatingForUser(String userId) {
    final userRatings = getRatingsForUser(userId);
    if (userRatings.isEmpty) return 0;
    final total = userRatings.fold<int>(0, (sum, r) => sum + r.rating);
    return total / userRatings.length;
  }

  Future<void> addRating(RatingModel rating) async {
    try {
      await _fs.setRating(rating);
      _ratings.add(rating);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menyimpan rating.', e);
    }
  }

  // ===========================================================================
  // PARTNER methods
  // ===========================================================================

  List<PartnerModel> getActivePartners() {
    return _partners.where((p) => p.isActive).toList();
  }

  Future<void> addPartner(PartnerModel partner) async {
    try {
      await _fs.setPartner(partner);
      _partners.add(partner);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menyimpan partner.', e);
    }
  }

  Future<void> updatePartner(PartnerModel partner) async {
    try {
      await _fs.updatePartner(partner);
      final idx = _partners.indexWhere((p) => p.id == partner.id);
      if (idx != -1) _partners[idx] = partner;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mengupdate partner.', e);
    }
  }

  Future<void> deletePartner(String id) async {
    try {
      await _fs.deletePartner(id);
      _partners.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus partner.', e);
    }
  }

  // ===========================================================================
  // MATCH RESULT methods
  // ===========================================================================

  List<MatchResultModel> getMatchResultsForSession(String sessionId) {
    final results = _matchResults.where((m) => m.sessionId == sessionId).toList();
    results.sort((a, b) => a.round.compareTo(b.round));
    return results;
  }

  List<MatchResultModel> getMatchResultsForUser(String userId) {
    return _matchResults
        .where((m) => m.allPlayerIds.contains(userId))
        .toList();
  }

  Future<void> addMatchResult(MatchResultModel result) async {
    try {
      await _fs.setMatchResult(result);
      _matchResults.add(result);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menyimpan hasil pertandingan.', e);
    }
  }

  Future<void> deleteMatchResult(String id) async {
    try {
      await _fs.deleteMatchResult(id);
      _matchResults.removeWhere((m) => m.id == id);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus hasil pertandingan.', e);
    }
  }

  // ===========================================================================
  // CHIPS TRANSACTION methods
  // ===========================================================================

  List<ChipsTransactionModel> getChipsTransactionsForUser(String userId) {
    return _chipsTransactions.where((t) => t.userId == userId).toList();
  }

  Future<void> addChipsTransaction(ChipsTransactionModel txn) async {
    try {
      await _fs.setChipsTransaction(txn);
      _chipsTransactions.add(txn);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menyimpan transaksi chips.', e);
    }
  }

  /// Atomic: write transaction + update user balance in one Firestore transaction.
  /// Balance is read inside the transaction to prevent TOCTOU races.
  Future<void> awardChipsAtomic({
    required ChipsTransactionModel txn,
    required String userId,
    required int amount,
  }) async {
    try {
      await _fs.awardChipsTransaction(
        txn: txn,
        userId: userId,
        amount: amount,
      );
      _chipsTransactions.add(txn);
      // Refresh local cache with the amount delta (actual balance is
      // authoritative in Firestore, computed inside the transaction).
      final userIdx = _users.indexWhere((u) => u.id == userId);
      if (userIdx != -1) {
        final current = _users[userIdx].chipsBalance;
        _users[userIdx] =
            _users[userIdx].copyWith(chipsBalance: current + amount);
      }
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal award chips.', e);
    }
  }

  /// Atomic array union on a Firestore document field.
  /// Uses FieldValue.arrayUnion for safe concurrent merges.
  Future<void> atomicArrayUnion({
    required String collection,
    required String docId,
    required String field,
    required List<String> values,
  }) async {
    await _fs.atomicArrayUnion(
      collection: collection,
      docId: docId,
      field: field,
      values: values,
    );
  }

  // ===========================================================================
  // AWARD methods
  // ===========================================================================

  List<AwardModel> getAwardsForUser(String userId) {
    return _awards.where((a) => a.userId == userId).toList();
  }

  List<AwardModel> getAwardsForPeriod(String period) {
    return _awards.where((a) => a.period == period).toList();
  }

  Future<void> addAward(AwardModel award) async {
    try {
      await _fs.setAward(award);
      _awards.add(award);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menyimpan award.', e);
    }
  }

  Future<void> deleteAward(String id) async {
    try {
      await _fs.deleteAward(id);
      _awards.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus award.', e);
    }
  }

  // ===========================================================================
  // REDEMPTION methods
  // ===========================================================================

  List<RedemptionModel> getRedemptionsForUser(String userId) {
    return _redemptions.where((r) => r.userId == userId).toList();
  }

  Future<void> addRedemption(RedemptionModel redemption) async {
    try {
      await _fs.setRedemption(redemption);
      _redemptions.add(redemption);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menyimpan redemption.', e);
    }
  }

  Future<void> updateRedemption(RedemptionModel redemption) async {
    try {
      await _fs.updateRedemption(redemption);
      final idx = _redemptions.indexWhere((r) => r.id == redemption.id);
      if (idx != -1) {
        _redemptions[idx] = redemption;
      } else {
        _redemptions.add(redemption);
      }
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal update redemption.', e);
    }
  }

  // ===========================================================================
  // REFERRAL methods
  // ===========================================================================

  List<ReferralModel> getReferralsForUser(String userId) {
    return _referrals.where((r) => r.referrerId == userId).toList();
  }

  ReferralModel? getReferralByCode(String code) {
    try {
      return _referrals.firstWhere((r) => r.referralCode == code);
    } catch (_) {
      return null;
    }
  }

  Future<void> addReferral(ReferralModel referral) async {
    try {
      await _fs.setReferral(referral);
      _referrals.add(referral);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menyimpan referral.', e);
    }
  }

  Future<void> updateReferral(ReferralModel referral) async {
    try {
      await _fs.updateReferral(referral);
      final idx = _referrals.indexWhere((r) => r.id == referral.id);
      if (idx != -1) {
        _referrals[idx] = referral;
      } else {
        _referrals.add(referral);
      }
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal update referral.', e);
    }
  }

  // ===========================================================================
  // ATTENDANCE methods
  // ===========================================================================

  Future<void> markAttendance(String slotId) async {
    final idx = _slots.indexWhere((s) => s.id == slotId);
    if (idx == -1) return;
    final updated = _slots[idx].copyWith(attendedAt: DateTime.now());
    try {
      await _fs.updateSlot(updated);
      _slots[idx] = updated;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mencatat kehadiran.', e);
    }
  }

  Future<void> unmarkAttendance(String slotId) async {
    final idx = _slots.indexWhere((s) => s.id == slotId);
    if (idx == -1) return;
    // Create a new slot without attendedAt
    final slot = _slots[idx];
    final updated = SlotModel(
      id: slot.id,
      sessionId: slot.sessionId,
      userId: slot.userId,
      userName: slot.userName,
      status: slot.status,
      joinedAt: slot.joinedAt,
      confirmedAt: slot.confirmedAt,
    );
    try {
      await _fs.updateSlot(updated);
      _slots[idx] = updated;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus catatan kehadiran.', e);
    }
  }

  // ===========================================================================
  // SESSION PHOTO methods
  // ===========================================================================

  List<String> getPhotosForSession(String sessionId) {
    final session = getSessionById(sessionId);
    return session?.photoUrls ?? [];
  }

  void addPhotoToSession(String sessionId, String photoPath) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    final session = _sessions[idx];
    final updated = session.copyWith(
      photoUrls: [...session.photoUrls, photoPath],
    );
    _sessions[idx] = updated;
    notifyListeners();
  }

  void removePhotoFromSession(String sessionId, String photoPath) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    final session = _sessions[idx];
    final updated = session.copyWith(
      photoUrls: session.photoUrls.where((p) => p != photoPath).toList(),
    );
    _sessions[idx] = updated;
    notifyListeners();
  }

  // ===========================================================================
  // SESSION methods
  // ===========================================================================
  SessionModel? getSessionById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<SessionModel> getSessionsByStatus(SessionStatus status) {
    return _sessions.where((s) => s.status == status).toList();
  }

  List<SessionModel> getSessionsByMimin(String miminId) {
    return _sessions.where((s) => s.miminId == miminId).toList();
  }

  Future<void> addSession(SessionModel session) async {
    try {
      await _fs.setSession(session);
      _sessions.add(session);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal membuat sesi.', e);
    }
  }

  Future<void> updateSession(SessionModel session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) return;

    try {
      await _fs.updateSession(session);
      _sessions[index] = session;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mengupdate sesi.', e);
    }
  }

  Future<void> removeSession(String sessionId) async {
    try {
      await _fs.removeSession(sessionId);
      _sessions.removeWhere((s) => s.id == sessionId);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus sesi.', e);
    }
  }

  // ===========================================================================
  // SLOT methods
  // ===========================================================================
  SlotModel? getSlotById(String id) {
    try {
      return _slots.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<SlotModel> getSlotsForSession(String sessionId) {
    return _slots.where((s) => s.sessionId == sessionId).toList();
  }

  List<SlotModel> getSlotsForUser(String userId) {
    return _slots.where((s) => s.userId == userId).toList();
  }

  Future<void> addSlot(SlotModel slot) async {
    try {
      await _fs.setSlot(slot);
      _slots.add(slot);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mendaftar slot.', e);
    }
  }

  Future<void> updateSlot(SlotModel slot) async {
    final index = _slots.indexWhere((s) => s.id == slot.id);
    if (index == -1) return;

    try {
      await _fs.updateSlot(slot);
      _slots[index] = slot;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mengupdate slot.', e);
    }
  }

  Future<void> removeSlot(String slotId) async {
    try {
      await _fs.removeSlot(slotId);
      _slots.removeWhere((s) => s.id == slotId);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus slot.', e);
    }
  }

  // ===========================================================================
  // PAYMENT methods
  // ===========================================================================
  PaymentModel? getPaymentById(String id) {
    try {
      return _payments.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<PaymentModel> getPaymentsForSession(String sessionId) {
    return _payments.where((p) => p.sessionId == sessionId).toList();
  }

  List<PaymentModel> getPaymentsForUser(String userId) {
    return _payments.where((p) => p.userId == userId).toList();
  }

  PaymentModel? getPaymentForSlot(String slotId) {
    try {
      return _payments.firstWhere((p) => p.slotId == slotId);
    } catch (_) {
      return null;
    }
  }

  Future<void> addPayment(PaymentModel payment) async {
    try {
      await _fs.setPayment(payment);
      _payments.add(payment);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mengirim pembayaran.', e);
    }
  }

  Future<void> updatePayment(PaymentModel payment) async {
    final index = _payments.indexWhere((p) => p.id == payment.id);
    if (index == -1) return;

    try {
      await _fs.updatePayment(payment);
      _payments[index] = payment;
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal mengupdate pembayaran.', e);
    }
  }

  Future<void> removePayment(String paymentId) async {
    try {
      await _fs.removePayment(paymentId);
      _payments.removeWhere((p) => p.id == paymentId);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus pembayaran.', e);
    }
  }

  // ===========================================================================
  // CASHFLOW methods
  // ===========================================================================
  List<CashFlowModel> getCashFlowsForSession(String sessionId) {
    return _cashflows.where((c) => c.sessionId == sessionId).toList();
  }

  Future<void> addCashFlow(CashFlowModel cashflow) async {
    try {
      await _fs.setCashFlow(cashflow);
      _cashflows.add(cashflow);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menambah catatan kas.', e);
    }
  }

  Future<void> removeCashFlow(String cashflowId) async {
    try {
      await _fs.removeCashFlow(cashflowId);
      _cashflows.removeWhere((c) => c.id == cashflowId);
      notifyListeners();
    } catch (e) {
      throw DataWriteException('Gagal menghapus catatan kas.', e);
    }
  }

  int getTotalIncome() {
    return _cashflows
        .where((c) => c.type == CashFlowType.income)
        .fold(0, (sum, c) => sum + c.amount);
  }

  int getTotalExpense() {
    return _cashflows
        .where((c) => c.type == CashFlowType.expense)
        .fold(0, (sum, c) => sum + c.amount);
  }

  int getBalance() {
    return getTotalIncome() - getTotalExpense();
  }

  // ===========================================================================
  // ATOMIC OPERATIONS (Firestore Transactions)
  // ===========================================================================

  /// Atomically join a session. Prevents overbooking via Firestore transaction.
  Future<SlotModel> joinSessionAtomic({
    required String sessionId,
    required String userId,
    required String userName,
    required String newSlotId,
  }) async {
    try {
      final slot = await _fs.joinSessionTransaction(
        sessionId: sessionId,
        userId: userId,
        userName: userName,
        newSlotId: newSlotId,
      );

      // Sync cache
      _slots.add(slot);
      if (slot.status != SlotStatus.waitlist) {
        final session = getSessionById(sessionId);
        if (session != null) {
          final confirmedCount = getSlotsForSession(sessionId)
              .where((s) =>
                  s.status == SlotStatus.confirmed ||
                  s.status == SlotStatus.paid ||
                  s.status == SlotStatus.locked)
              .length;
          if (confirmedCount >= session.maxPlayers &&
              session.status != SessionStatus.full) {
            final idx = _sessions.indexWhere((s) => s.id == sessionId);
            if (idx != -1) {
              _sessions[idx] = session.copyWith(status: SessionStatus.full);
            }
          }
        }
      }

      notifyListeners();
      return slot;
    } on ConflictException {
      rethrow;
    } catch (e) {
      throw DataWriteException('Gagal join sesi.', e);
    }
  }

  /// Atomically leave a session with waitlist promotion.
  Future<void> leaveSessionAtomic({
    required String sessionId,
    required String userId,
  }) async {
    final slots = getSlotsForSession(sessionId);
    final userSlots = slots.where((s) => s.userId == userId).toList();
    if (userSlots.isEmpty) return;

    final wasConfirmed = userSlots.any((s) =>
        s.status == SlotStatus.confirmed ||
        s.status == SlotStatus.paid ||
        s.status == SlotStatus.locked);

    final payments = getPaymentsForSession(sessionId);
    final userPayments = payments.where((p) => p.userId == userId).toList();

    String? waitlistSlotId;
    if (wasConfirmed) {
      final waitlisted = slots
          .where((s) => s.status == SlotStatus.waitlist)
          .toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      if (waitlisted.isNotEmpty) {
        waitlistSlotId = waitlisted.first.id;
      }
    }

    try {
      await _fs.leaveSessionTransaction(
        sessionId: sessionId,
        slotIdsToRemove: userSlots.map((s) => s.id).toList(),
        paymentIdsToRemove: userPayments.map((p) => p.id).toList(),
        wasConfirmed: wasConfirmed,
        waitlistSlotIdToPromote: waitlistSlotId,
      );

      // Sync cache: remove slots & payments
      for (final s in userSlots) {
        _slots.removeWhere((x) => x.id == s.id);
      }
      for (final p in userPayments) {
        _payments.removeWhere((x) => x.id == p.id);
      }

      if (wasConfirmed) {
        // Promote waitlist slot in cache
        if (waitlistSlotId != null) {
          final idx = _slots.indexWhere((s) => s.id == waitlistSlotId);
          if (idx != -1) {
            _slots[idx] = _slots[idx].copyWith(
              status: SlotStatus.confirmed,
              confirmedAt: DateTime.now(),
            );
          }
        }

        // Update session status in cache
        final session = getSessionById(sessionId);
        if (session != null && session.status == SessionStatus.full) {
          final confirmedNow = getSlotsForSession(sessionId)
              .where((s) =>
                  s.status == SlotStatus.confirmed ||
                  s.status == SlotStatus.paid ||
                  s.status == SlotStatus.locked)
              .length;
          if (confirmedNow < session.maxPlayers) {
            final idx = _sessions.indexWhere((s) => s.id == sessionId);
            if (idx != -1) {
              _sessions[idx] = session.copyWith(status: SessionStatus.open);
            }
          }
        }
      }

      notifyListeners();
    } on ConflictException {
      rethrow;
    } catch (e) {
      throw DataWriteException('Gagal keluar dari sesi.', e);
    }
  }

  /// Atomically verify a payment, update slot, and create cashflow entry.
  Future<void> verifyPaymentAtomic({
    required String paymentId,
    required String verifierId,
    required CashFlowModel cashflowEntry,
  }) async {
    final payment = getPaymentById(paymentId);
    if (payment == null) {
      throw const ConflictException('Pembayaran tidak ditemukan.');
    }

    try {
      await _fs.verifyPaymentTransaction(
        paymentId: paymentId,
        verifierId: verifierId,
        slotId: payment.slotId,
        cashflowEntry: cashflowEntry,
      );

      // Sync cache
      final payIdx = _payments.indexWhere((p) => p.id == paymentId);
      if (payIdx != -1) {
        _payments[payIdx] = payment.copyWith(
          status: PaymentStatus.verified,
          verifiedBy: verifierId,
          verifiedAt: DateTime.now(),
        );
      }

      final slotIdx = _slots.indexWhere((s) => s.id == payment.slotId);
      if (slotIdx != -1) {
        _slots[slotIdx] = _slots[slotIdx].copyWith(status: SlotStatus.paid);
      }

      _cashflows.add(cashflowEntry);
      notifyListeners();
    } on ConflictException {
      rethrow;
    } catch (e) {
      throw DataWriteException('Gagal verifikasi pembayaran.', e);
    }
  }

  // ===========================================================================
  // FALLBACK: Local-only seed (if Firestore unavailable)
  // ===========================================================================
  void _seedLocalOnly() {
    AppLogger.w('DataService', 'Using local-only seed data (Firestore unavailable)');
    final now = DateTime.now();

    // ---- 12 Users ----
    _users.addAll([
      UserModel(id: 'user-reza', name: 'Reza Rahadian', phone: '08119990001', role: UserRole.superAdmin, createdAt: now.subtract(const Duration(days: 180)), nickname: 'Reza', bio: 'Founder Daddies Padel Community. Suka ngajak main & ngumpul bareng.', skillLevel: SkillLevel.mahir),
      UserModel(id: 'user-hendy', name: 'Hendy Wijaya', phone: '08119990002', role: UserRole.mimin, createdAt: now.subtract(const Duration(days: 170)), nickname: 'Hendy', bio: 'Mimin andalan yang selalu rajin booking court. Backhand enthusiast.', skillLevel: SkillLevel.mahir),
      UserModel(id: 'user-bima', name: 'Bima Sakti', phone: '08119990003', role: UserRole.mimin, createdAt: now.subtract(const Duration(days: 165)), nickname: 'Bima', bio: 'Mimin night session. Kalau bola mental, dia yang paling semangat.', skillLevel: SkillLevel.menengah),
      UserModel(id: 'user-fajar', name: 'Fajar Nugroho', phone: '08119990004', role: UserRole.bendahara, createdAt: now.subtract(const Duration(days: 160)), nickname: 'Fajar', bio: 'Bendahara yang selalu tepat hitung. Juga jago lob!', skillLevel: SkillLevel.menengah),
      UserModel(id: 'user-arif', name: 'Arif Budiman', phone: '08129990005', role: UserRole.member, createdAt: now.subtract(const Duration(days: 120)), nickname: 'Arif', bio: 'Newbie yang progresnya cepat. Suka drill pagi-pagi.', skillLevel: SkillLevel.pemula),
      UserModel(id: 'user-denny', name: 'Denny Pratama', phone: '08139990006', role: UserRole.member, createdAt: now.subtract(const Duration(days: 110)), nickname: 'Den', bio: 'Pemain all-round. Bisa main depan, bisa main belakang.', skillLevel: SkillLevel.menengah),
      UserModel(id: 'user-gilang', name: 'Gilang Ramadhan', phone: '08159990007', role: UserRole.member, createdAt: now.subtract(const Duration(days: 100)), nickname: 'Gilang', bio: 'Smash keras, tapi kadang keluar. Semangat terus!', skillLevel: SkillLevel.pemula),
      UserModel(id: 'user-raka', name: 'Raka Aditya', phone: '08179990008', role: UserRole.member, createdAt: now.subtract(const Duration(days: 95)), nickname: 'Raka', bio: 'Si strategis yang suka main placement. Tenang tapi mematikan.', skillLevel: SkillLevel.mahir),
      UserModel(id: 'user-tommy', name: 'Tommy Hartono', phone: '08189990009', role: UserRole.member, createdAt: now.subtract(const Duration(days: 80)), nickname: 'Tom', bio: 'Tembok pertahanan. Susah dilewati kalau jaga belakang.', skillLevel: SkillLevel.menengah),
      UserModel(id: 'user-andre', name: 'Andre Kusuma', phone: '08199990010', role: UserRole.member, createdAt: now.subtract(const Duration(days: 70)), nickname: 'Andre', bio: 'Spesialis net play. Volley-nya tajam dan akurat.', skillLevel: SkillLevel.mahir),
      UserModel(id: 'user-bayu', name: 'Bayu Pratomo', phone: '08211990011', role: UserRole.member, createdAt: now.subtract(const Duration(days: 45)), nickname: 'Bayu', bio: 'Morning person yang suka padel sebelum ngantor.', skillLevel: SkillLevel.pemula),
      UserModel(id: 'user-cahyo', name: 'Cahyo Wibowo', phone: '08221990012', role: UserRole.member, createdAt: now.subtract(const Duration(days: 30)), nickname: 'Cah', bio: 'Weekend warrior. Cuma bisa main Sabtu-Minggu tapi serius!', skillLevel: SkillLevel.pemula),
    ]);

    final reza = _users[0], hendy = _users[1], bima = _users[2], fajar = _users[3];
    final arif = _users[4], denny = _users[5], gilang = _users[6], raka = _users[7];
    final tommy = _users[8], andre = _users[9], bayu = _users[10], cahyo = _users[11];

    // ---- 3 Venues ----
    _venues.addAll([
      const VenueModel(
        id: 'venue-genesis',
        name: 'Genesis Padel',
        address: 'Jl. Jalur Sutera Barat No.15, Alam Sutera, Tangerang Selatan',
        bio: 'Genesis Padel adalah venue padel premium pertama di kawasan Alam Sutera. Dengan 4 lapangan standar internasional dan fasilitas lengkap, Genesis menjadi rumah kedua bagi komunitas Daddies Padel. Suasana nyaman, pencahayaan optimal, dan parkir luas membuat setiap sesi bermain terasa spesial.',
        phone: '021-29880123',
        facilities: ['Indoor Courts', 'Parkir Luas', 'Musholla', 'Kantin', 'Pro Shop', 'Shower & Locker'],
        courtCount: 4,
        openHours: '06:00 - 23:00',
      ),
      const VenueModel(
        id: 'venue-haus',
        name: 'Padel Haus BSD',
        address: 'Jl. BSD Grand Boulevard, BSD City, Tangerang Selatan',
        bio: 'Padel Haus BSD hadir dengan konsep modern-industrial yang kekinian. Terletak di jantung BSD City, venue ini mudah diakses dan cocok untuk sesi siang maupun malam. Court berkualitas tinggi dengan kaca tempered dan rumput sintetis premium menjamin pengalaman bermain terbaik.',
        phone: '021-53167890',
        facilities: ['Indoor Courts', 'Café & Lounge', 'Parkir Luas', 'Shower', 'Free WiFi', 'Rental Raket'],
        courtCount: 3,
        openHours: '07:00 - 22:00',
      ),
      const VenueModel(
        id: 'venue-pik',
        name: 'The Padel Club PIK',
        address: 'Jl. Pantai Indah Utara 2, Pantai Indah Kapuk, Jakarta Utara',
        bio: 'The Padel Club PIK adalah destinasi padel eksklusif di kawasan PIK. Dengan view laut dan desain arsitektur kontemporer, venue ini menawarkan pengalaman bermain padel yang berbeda. Lapangan outdoor dengan atap retractable memungkinkan bermain di segala cuaca sambil menikmati angin laut.',
        phone: '021-66601234',
        facilities: ['Semi-Outdoor Courts', 'Restaurant', 'Valet Parking', 'Shower & Locker', 'Pro Shop', 'Kids Area'],
        courtCount: 5,
        openHours: '06:00 - 22:00',
      ),
    ]);

    // ---- 8 Sessions ----
    _sessions.addAll([
      SessionModel(id: 'session-1', miminId: hendy.id, miminName: hendy.name, title: 'Mabar Sabtu Sore', venue: 'Genesis Padel', date: now.subtract(const Duration(days: 28)), timeStart: '16:00', timeEnd: '18:00', maxPlayers: 8, pricePerPlayer: 150000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 32)), notes: 'Bawa bola sendiri ya!', courtNumber: 2),
      SessionModel(id: 'session-2', miminId: bima.id, miminName: bima.name, title: 'Rabu Siang Chill', venue: 'Padel Haus BSD', date: now.subtract(const Duration(days: 21)), timeStart: '12:00', timeEnd: '14:00', maxPlayers: 8, pricePerPlayer: 125000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 25))),
      SessionModel(id: 'session-3', miminId: hendy.id, miminName: hendy.name, title: 'Friday Night Smash', venue: 'The Padel Club PIK', date: now.subtract(const Duration(days: 14)), timeStart: '19:00', timeEnd: '21:00', maxPlayers: 8, pricePerPlayer: 200000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 18)), notes: 'Night session, pakai sepatu indoor', courtNumber: 1),
      SessionModel(id: 'session-4', miminId: bima.id, miminName: bima.name, title: 'Weekend Warriors', venue: 'Genesis Padel', date: now.subtract(const Duration(days: 7)), timeStart: '08:00', timeEnd: '10:00', maxPlayers: 8, pricePerPlayer: 150000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 10))),
      SessionModel(id: 'session-5', miminId: bima.id, miminName: bima.name, title: 'Jumat Night Session', venue: 'Padel Haus BSD', date: now.add(const Duration(days: 2)), timeStart: '19:00', timeEnd: '21:00', maxPlayers: 8, pricePerPlayer: 175000, status: SessionStatus.locked, createdAt: now.subtract(const Duration(days: 5)), courtNumber: 3),
      SessionModel(id: 'session-6', miminId: hendy.id, miminName: hendy.name, title: 'Sunday Funday', venue: 'The Padel Club PIK', date: now.add(const Duration(days: 4)), timeStart: '09:00', timeEnd: '11:00', maxPlayers: 8, pricePerPlayer: 200000, status: SessionStatus.open, createdAt: now.subtract(const Duration(days: 3)), notes: 'Pemula welcome! Kita main santai.', courtNumber: 4),
      SessionModel(id: 'session-7', miminId: hendy.id, miminName: hendy.name, title: 'Senin Pagi Semangat', venue: 'Padel Haus BSD', date: now.add(const Duration(days: 8)), timeStart: '07:00', timeEnd: '09:00', maxPlayers: 8, pricePerPlayer: 125000, status: SessionStatus.open, createdAt: now.subtract(const Duration(days: 1))),
      SessionModel(id: 'session-8', miminId: reza.id, miminName: reza.name, title: 'Daddies Cup Mini Tournament', venue: 'Genesis Padel', date: now.add(const Duration(days: 15)), timeStart: '08:00', timeEnd: '12:00', maxPlayers: 16, pricePerPlayer: 250000, status: SessionStatus.draft, createdAt: now, notes: 'Mini tournament format: round robin lalu semifinal. Bawa jersey tim!', courtNumber: 1),
    ]);

    // ---- Slots (~55) ----
    _slots.addAll([
      // Session 1: 8 locked (completed, full roster)
      SlotModel(id: 'slot-1a', sessionId: 'session-1', userId: arif.id, userName: arif.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 30)), confirmedAt: now.subtract(const Duration(days: 29))),
      SlotModel(id: 'slot-1b', sessionId: 'session-1', userId: denny.id, userName: denny.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 30)), confirmedAt: now.subtract(const Duration(days: 29))),
      SlotModel(id: 'slot-1c', sessionId: 'session-1', userId: gilang.id, userName: gilang.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 30)), confirmedAt: now.subtract(const Duration(days: 29))),
      SlotModel(id: 'slot-1d', sessionId: 'session-1', userId: raka.id, userName: raka.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 30)), confirmedAt: now.subtract(const Duration(days: 29))),
      SlotModel(id: 'slot-1e', sessionId: 'session-1', userId: hendy.id, userName: hendy.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 30)), confirmedAt: now.subtract(const Duration(days: 29))),
      SlotModel(id: 'slot-1f', sessionId: 'session-1', userId: bima.id, userName: bima.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 30)), confirmedAt: now.subtract(const Duration(days: 29))),
      SlotModel(id: 'slot-1g', sessionId: 'session-1', userId: fajar.id, userName: fajar.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 29)), confirmedAt: now.subtract(const Duration(days: 29))),
      SlotModel(id: 'slot-1h', sessionId: 'session-1', userId: reza.id, userName: reza.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 29)), confirmedAt: now.subtract(const Duration(days: 29))),
      // Session 2: 6 locked (completed, smaller group)
      SlotModel(id: 'slot-2a', sessionId: 'session-2', userId: denny.id, userName: denny.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 23)), confirmedAt: now.subtract(const Duration(days: 22))),
      SlotModel(id: 'slot-2b', sessionId: 'session-2', userId: gilang.id, userName: gilang.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 23)), confirmedAt: now.subtract(const Duration(days: 22))),
      SlotModel(id: 'slot-2c', sessionId: 'session-2', userId: bima.id, userName: bima.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 23)), confirmedAt: now.subtract(const Duration(days: 22))),
      SlotModel(id: 'slot-2d', sessionId: 'session-2', userId: tommy.id, userName: tommy.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 22)), confirmedAt: now.subtract(const Duration(days: 22))),
      SlotModel(id: 'slot-2e', sessionId: 'session-2', userId: andre.id, userName: andre.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 22)), confirmedAt: now.subtract(const Duration(days: 22))),
      SlotModel(id: 'slot-2f', sessionId: 'session-2', userId: fajar.id, userName: fajar.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 22)), confirmedAt: now.subtract(const Duration(days: 22))),
      // Session 3: 8 locked (completed, full)
      SlotModel(id: 'slot-3a', sessionId: 'session-3', userId: arif.id, userName: arif.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 16)), confirmedAt: now.subtract(const Duration(days: 15))),
      SlotModel(id: 'slot-3b', sessionId: 'session-3', userId: raka.id, userName: raka.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 16)), confirmedAt: now.subtract(const Duration(days: 15))),
      SlotModel(id: 'slot-3c', sessionId: 'session-3', userId: hendy.id, userName: hendy.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 16)), confirmedAt: now.subtract(const Duration(days: 15))),
      SlotModel(id: 'slot-3d', sessionId: 'session-3', userId: tommy.id, userName: tommy.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 15)), confirmedAt: now.subtract(const Duration(days: 15))),
      SlotModel(id: 'slot-3e', sessionId: 'session-3', userId: andre.id, userName: andre.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 15)), confirmedAt: now.subtract(const Duration(days: 15))),
      SlotModel(id: 'slot-3f', sessionId: 'session-3', userId: denny.id, userName: denny.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 15)), confirmedAt: now.subtract(const Duration(days: 15))),
      SlotModel(id: 'slot-3g', sessionId: 'session-3', userId: gilang.id, userName: gilang.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 15)), confirmedAt: now.subtract(const Duration(days: 14))),
      SlotModel(id: 'slot-3h', sessionId: 'session-3', userId: fajar.id, userName: fajar.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 15)), confirmedAt: now.subtract(const Duration(days: 14))),
      // Session 4: 7 locked (completed, almost full)
      SlotModel(id: 'slot-4a', sessionId: 'session-4', userId: arif.id, userName: arif.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 9)), confirmedAt: now.subtract(const Duration(days: 8))),
      SlotModel(id: 'slot-4b', sessionId: 'session-4', userId: denny.id, userName: denny.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 9)), confirmedAt: now.subtract(const Duration(days: 8))),
      SlotModel(id: 'slot-4c', sessionId: 'session-4', userId: raka.id, userName: raka.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 9)), confirmedAt: now.subtract(const Duration(days: 8))),
      SlotModel(id: 'slot-4d', sessionId: 'session-4', userId: bima.id, userName: bima.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 9)), confirmedAt: now.subtract(const Duration(days: 8))),
      SlotModel(id: 'slot-4e', sessionId: 'session-4', userId: bayu.id, userName: bayu.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 8)), confirmedAt: now.subtract(const Duration(days: 8))),
      SlotModel(id: 'slot-4f', sessionId: 'session-4', userId: cahyo.id, userName: cahyo.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 8)), confirmedAt: now.subtract(const Duration(days: 8))),
      SlotModel(id: 'slot-4g', sessionId: 'session-4', userId: tommy.id, userName: tommy.name, status: SlotStatus.locked, joinedAt: now.subtract(const Duration(days: 8)), confirmedAt: now.subtract(const Duration(days: 8))),
      // Session 5: 6 paid, 1 confirmed, 1 waitlist (locked upcoming)
      SlotModel(id: 'slot-5a', sessionId: 'session-5', userId: arif.id, userName: arif.name, status: SlotStatus.paid, joinedAt: now.subtract(const Duration(days: 4)), confirmedAt: now.subtract(const Duration(days: 3))),
      SlotModel(id: 'slot-5b', sessionId: 'session-5', userId: denny.id, userName: denny.name, status: SlotStatus.paid, joinedAt: now.subtract(const Duration(days: 4)), confirmedAt: now.subtract(const Duration(days: 3))),
      SlotModel(id: 'slot-5c', sessionId: 'session-5', userId: gilang.id, userName: gilang.name, status: SlotStatus.paid, joinedAt: now.subtract(const Duration(days: 4)), confirmedAt: now.subtract(const Duration(days: 3))),
      SlotModel(id: 'slot-5d', sessionId: 'session-5', userId: raka.id, userName: raka.name, status: SlotStatus.paid, joinedAt: now.subtract(const Duration(days: 3)), confirmedAt: now.subtract(const Duration(days: 2))),
      SlotModel(id: 'slot-5e', sessionId: 'session-5', userId: bima.id, userName: bima.name, status: SlotStatus.paid, joinedAt: now.subtract(const Duration(days: 4)), confirmedAt: now.subtract(const Duration(days: 3))),
      SlotModel(id: 'slot-5f', sessionId: 'session-5', userId: fajar.id, userName: fajar.name, status: SlotStatus.paid, joinedAt: now.subtract(const Duration(days: 3)), confirmedAt: now.subtract(const Duration(days: 2))),
      SlotModel(id: 'slot-5g', sessionId: 'session-5', userId: hendy.id, userName: hendy.name, status: SlotStatus.confirmed, joinedAt: now.subtract(const Duration(days: 2)), confirmedAt: now.subtract(const Duration(days: 1))),
      SlotModel(id: 'slot-5h', sessionId: 'session-5', userId: tommy.id, userName: tommy.name, status: SlotStatus.waitlist, joinedAt: now.subtract(const Duration(days: 1))),
      // Session 6: 5 confirmed (open, filling up)
      SlotModel(id: 'slot-6a', sessionId: 'session-6', userId: arif.id, userName: arif.name, status: SlotStatus.confirmed, joinedAt: now.subtract(const Duration(days: 2)), confirmedAt: now.subtract(const Duration(days: 2))),
      SlotModel(id: 'slot-6b', sessionId: 'session-6', userId: andre.id, userName: andre.name, status: SlotStatus.confirmed, joinedAt: now.subtract(const Duration(days: 2)), confirmedAt: now.subtract(const Duration(days: 1))),
      SlotModel(id: 'slot-6c', sessionId: 'session-6', userId: cahyo.id, userName: cahyo.name, status: SlotStatus.confirmed, joinedAt: now.subtract(const Duration(days: 1)), confirmedAt: now.subtract(const Duration(days: 1))),
      SlotModel(id: 'slot-6d', sessionId: 'session-6', userId: bayu.id, userName: bayu.name, status: SlotStatus.confirmed, joinedAt: now.subtract(const Duration(hours: 20)), confirmedAt: now.subtract(const Duration(hours: 18))),
      SlotModel(id: 'slot-6e', sessionId: 'session-6', userId: hendy.id, userName: hendy.name, status: SlotStatus.confirmed, joinedAt: now.subtract(const Duration(hours: 12)), confirmedAt: now.subtract(const Duration(hours: 10))),
      // Session 7: 2 registered (open, early)
      SlotModel(id: 'slot-7a', sessionId: 'session-7', userId: bayu.id, userName: bayu.name, status: SlotStatus.registered, joinedAt: now.subtract(const Duration(hours: 10))),
      SlotModel(id: 'slot-7b', sessionId: 'session-7', userId: arif.id, userName: arif.name, status: SlotStatus.registered, joinedAt: now.subtract(const Duration(hours: 4))),
    ]);

    // ---- Cashflows (16 entries) ----
    _cashflows.addAll([
      // Session 1 financials
      CashFlowModel(id: 'cf-01', type: CashFlowType.income, category: 'Session Fee', amount: 1200000, sessionId: 'session-1', description: 'Pemasukan sesi Mabar Sabtu Sore (8 x Rp150.000)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 28))),
      CashFlowModel(id: 'cf-02', type: CashFlowType.expense, category: 'Court Rental', amount: 800000, sessionId: 'session-1', description: 'Sewa lapangan Genesis Padel 2 jam', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 28))),
      // Session 2 financials
      CashFlowModel(id: 'cf-03', type: CashFlowType.income, category: 'Session Fee', amount: 750000, sessionId: 'session-2', description: 'Pemasukan sesi Rabu Siang Chill (6 x Rp125.000)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 21))),
      CashFlowModel(id: 'cf-04', type: CashFlowType.expense, category: 'Court Rental', amount: 600000, sessionId: 'session-2', description: 'Sewa lapangan Padel Haus BSD 2 jam (siang)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 21))),
      // Session 3 financials
      CashFlowModel(id: 'cf-05', type: CashFlowType.income, category: 'Session Fee', amount: 1600000, sessionId: 'session-3', description: 'Pemasukan sesi Friday Night Smash (8 x Rp200.000)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 14))),
      CashFlowModel(id: 'cf-06', type: CashFlowType.expense, category: 'Court Rental', amount: 1000000, sessionId: 'session-3', description: 'Sewa lapangan The Padel Club PIK 2 jam (malam)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 14))),
      CashFlowModel(id: 'cf-07', type: CashFlowType.expense, category: 'Equipment', amount: 180000, sessionId: 'session-3', description: 'Bola padel Head Pro S (1 tabung)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 14))),
      // Session 4 financials
      CashFlowModel(id: 'cf-08', type: CashFlowType.income, category: 'Session Fee', amount: 1050000, sessionId: 'session-4', description: 'Pemasukan sesi Weekend Warriors (7 x Rp150.000)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 7))),
      CashFlowModel(id: 'cf-09', type: CashFlowType.expense, category: 'Court Rental', amount: 800000, sessionId: 'session-4', description: 'Sewa lapangan Genesis Padel 2 jam (pagi)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 7))),
      // Session 5 financials (partial - locked, some paid)
      CashFlowModel(id: 'cf-10', type: CashFlowType.income, category: 'Session Fee', amount: 1050000, sessionId: 'session-5', description: 'Pemasukan sesi Jumat Night (6 x Rp175.000, sementara)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 2))),
      CashFlowModel(id: 'cf-11', type: CashFlowType.expense, category: 'Court Rental', amount: 900000, sessionId: 'session-5', description: 'Sewa lapangan Padel Haus BSD 2 jam (malam)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 2))),
      // Equipment & community expenses
      CashFlowModel(id: 'cf-12', type: CashFlowType.expense, category: 'Equipment', amount: 450000, description: 'Stok bola padel Bullpadel Premium Pro (3 tabung)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 25))),
      CashFlowModel(id: 'cf-13', type: CashFlowType.expense, category: 'Equipment', amount: 120000, description: 'Overgrip Babolat VS Original (pack isi 12)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 18))),
      CashFlowModel(id: 'cf-14', type: CashFlowType.expense, category: 'Equipment', amount: 350000, description: 'Grip tape Bullpadel + vibration dampener set', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 10))),
      CashFlowModel(id: 'cf-15', type: CashFlowType.income, category: 'Membership', amount: 800000, description: 'Iuran bulanan komunitas Januari (8 member x Rp100.000)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 45))),
      CashFlowModel(id: 'cf-16', type: CashFlowType.income, category: 'Membership', amount: 1200000, description: 'Iuran bulanan komunitas Februari (12 member x Rp100.000)', recordedBy: fajar.name, createdAt: now.subtract(const Duration(days: 15))),
    ]);

    // ---- Partners ----
    _partners.addAll([
      PartnerModel(id: 'partner-genesis', name: 'Genesis Padel', category: 'Venue', discountPercent: 10, discountDescription: 'Diskon 10% sewa lapangan untuk anggota Daddies', address: 'Jl. Jalur Sutera Barat No.15, Alam Sutera', phone: '021-29880123', isActive: true, createdAt: now.subtract(const Duration(days: 90))),
      PartnerModel(id: 'partner-physio', name: 'ProFit Physiotherapy', category: 'Kesehatan', discountPercent: 15, discountDescription: 'Diskon 15% fisioterapi & sport massage', address: 'Ruko BSD Junction Blok A12', phone: '0812-3456-7890', isActive: true, createdAt: now.subtract(const Duration(days: 60))),
      PartnerModel(id: 'partner-racket', name: 'Padel Store Indonesia', category: 'Equipment', discountPercent: 10, discountDescription: 'Diskon 10% semua raket & aksesoris padel', address: 'Mall Alam Sutera Lt. 2', phone: '0857-1234-5678', isActive: true, createdAt: now.subtract(const Duration(days: 45))),
      PartnerModel(id: 'partner-food', name: 'Warung Sehat BSD', category: 'F&B', discountPercent: 20, discountDescription: 'Diskon 20% menu healthy bowl & smoothie post-game', address: 'Jl. BSD Raya Utama No.88', phone: '0821-9876-5432', isActive: true, createdAt: now.subtract(const Duration(days: 30))),
    ]);

    // ---- Match Results (sessions 1, 3, 4 — completed sessions) ----
    _matchResults.addAll([
      // Session 1: 3 rounds (Americano style)
      MatchResultModel(id: 'mr-1a', sessionId: 'session-1', round: 1, team1PlayerIds: [arif.id, raka.id], team1PlayerNames: [arif.name, raka.name], team2PlayerIds: [hendy.id, denny.id], team2PlayerNames: [hendy.name, denny.name], team1Score: 6, team2Score: 4, createdAt: now.subtract(const Duration(days: 28))),
      MatchResultModel(id: 'mr-1b', sessionId: 'session-1', round: 2, team1PlayerIds: [bima.id, fajar.id], team1PlayerNames: [bima.name, fajar.name], team2PlayerIds: [gilang.id, reza.id], team2PlayerNames: [gilang.name, reza.name], team1Score: 5, team2Score: 5, createdAt: now.subtract(const Duration(days: 28))),
      MatchResultModel(id: 'mr-1c', sessionId: 'session-1', round: 3, team1PlayerIds: [arif.id, bima.id], team1PlayerNames: [arif.name, bima.name], team2PlayerIds: [raka.id, fajar.id], team2PlayerNames: [raka.name, fajar.name], team1Score: 7, team2Score: 3, createdAt: now.subtract(const Duration(days: 28))),
      // Session 3: 2 rounds
      MatchResultModel(id: 'mr-3a', sessionId: 'session-3', round: 1, team1PlayerIds: [arif.id, andre.id], team1PlayerNames: [arif.name, andre.name], team2PlayerIds: [raka.id, tommy.id], team2PlayerNames: [raka.name, tommy.name], team1Score: 6, team2Score: 6, createdAt: now.subtract(const Duration(days: 14))),
      MatchResultModel(id: 'mr-3b', sessionId: 'session-3', round: 2, team1PlayerIds: [hendy.id, raka.id], team1PlayerNames: [hendy.name, raka.name], team2PlayerIds: [arif.id, gilang.id], team2PlayerNames: [arif.name, gilang.name], team1Score: 7, team2Score: 4, createdAt: now.subtract(const Duration(days: 14))),
      // Session 4: 2 rounds
      MatchResultModel(id: 'mr-4a', sessionId: 'session-4', round: 1, team1PlayerIds: [denny.id, raka.id], team1PlayerNames: [denny.name, raka.name], team2PlayerIds: [arif.id, tommy.id], team2PlayerNames: [arif.name, tommy.name], team1Score: 6, team2Score: 5, createdAt: now.subtract(const Duration(days: 7))),
      MatchResultModel(id: 'mr-4b', sessionId: 'session-4', round: 2, team1PlayerIds: [bima.id, bayu.id], team1PlayerNames: [bima.name, bayu.name], team2PlayerIds: [denny.id, cahyo.id], team2PlayerNames: [denny.name, cahyo.name], team1Score: 4, team2Score: 6, createdAt: now.subtract(const Duration(days: 7))),
    ]);

    // ---- Ratings (session 1, 3, 4 — completed sessions) ----
    _ratings.addAll([
      // Session 1: Arif rates teammates
      RatingModel(id: 'rat-01', sessionId: 'session-1', fromUserId: arif.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-02', sessionId: 'session-1', fromUserId: arif.id, toUserId: hendy.id, toUserName: hendy.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-03', sessionId: 'session-1', fromUserId: arif.id, toUserId: denny.id, toUserName: denny.name, rating: 4, createdAt: now.subtract(const Duration(days: 27))),
      // Session 1: Raka rates teammates
      RatingModel(id: 'rat-04', sessionId: 'session-1', fromUserId: raka.id, toUserId: arif.id, toUserName: arif.name, rating: 4, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-05', sessionId: 'session-1', fromUserId: raka.id, toUserId: hendy.id, toUserName: hendy.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-06', sessionId: 'session-1', fromUserId: raka.id, toUserId: reza.id, toUserName: reza.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      // Session 3: Hendy rates teammates
      RatingModel(id: 'rat-07', sessionId: 'session-3', fromUserId: hendy.id, toUserId: arif.id, toUserName: arif.name, rating: 4, createdAt: now.subtract(const Duration(days: 13))),
      RatingModel(id: 'rat-08', sessionId: 'session-3', fromUserId: hendy.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 13))),
      RatingModel(id: 'rat-09', sessionId: 'session-3', fromUserId: hendy.id, toUserId: andre.id, toUserName: andre.name, rating: 5, createdAt: now.subtract(const Duration(days: 13))),
      RatingModel(id: 'rat-10', sessionId: 'session-3', fromUserId: hendy.id, toUserId: tommy.id, toUserName: tommy.name, rating: 4, createdAt: now.subtract(const Duration(days: 13))),
      // Session 4: Bima rates teammates
      RatingModel(id: 'rat-11', sessionId: 'session-4', fromUserId: bima.id, toUserId: arif.id, toUserName: arif.name, rating: 3, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-12', sessionId: 'session-4', fromUserId: bima.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-13', sessionId: 'session-4', fromUserId: bima.id, toUserId: tommy.id, toUserName: tommy.name, rating: 4, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-14', sessionId: 'session-4', fromUserId: bima.id, toUserId: bayu.id, toUserName: bayu.name, rating: 3, createdAt: now.subtract(const Duration(days: 6))),
      // Session 4: Denny rates teammates
      RatingModel(id: 'rat-15', sessionId: 'session-4', fromUserId: denny.id, toUserId: arif.id, toUserName: arif.name, rating: 4, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-16', sessionId: 'session-4', fromUserId: denny.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-17', sessionId: 'session-4', fromUserId: denny.id, toUserId: bima.id, toUserName: bima.name, rating: 4, createdAt: now.subtract(const Duration(days: 6))),
    ]);
  }
}
