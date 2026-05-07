import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';

import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/core/services/app_logger.dart';
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
import 'package:daddies_app/core/errors/app_exceptions.dart';
import 'package:daddies_app/core/resilience/circuit_breaker.dart';
import 'package:daddies_app/core/services/health_service.dart';

class FirestoreService {
  FirestoreService._() {
    // Register circuit breakers for health reporting.
    HealthService.instance.registerCircuitBreaker(readBreaker);
    HealthService.instance.registerCircuitBreaker(writeBreaker);
  }
  static final FirestoreService instance = FirestoreService._();

  /// Timeout for read operations (Release It! Ch.5 — Timeouts pattern).
  static const _readTimeout = Duration(seconds: 10);

  /// Timeout for write/transaction operations.
  static const _writeTimeout = Duration(seconds: 15);

  /// Maximum documents per unbounded query (Release It! Ch.4 — Unbounded
  /// Result Sets antipattern). Prevents memory exhaustion as data grows.
  static const _maxQueryResults = 500;

  /// Circuit breaker for read operations.
  final CircuitBreaker readBreaker = CircuitBreaker(
    name: 'firestore-read',
    failureThreshold: 5,
    cooldownDuration: const Duration(seconds: 30),
  );

  /// Circuit breaker for write operations.
  final CircuitBreaker writeBreaker = CircuitBreaker(
    name: 'firestore-write',
    failureThreshold: 3,
    cooldownDuration: const Duration(seconds: 20),
  );

  /// Wrap an async operation with a Firebase Performance custom trace.
  Future<T> _traced<T>(String traceName, Future<T> Function() operation) async {
    final trace = FirebasePerformance.instance.newTrace(traceName);
    await trace.start();
    try {
      final result = await operation();
      trace.putAttribute('success', 'true');
      return result;
    } catch (e) {
      trace.putAttribute('success', 'false');
      trace.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _slots =>
      _db.collection('slots');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('payments');
  CollectionReference<Map<String, dynamic>> get _cashflows =>
      _db.collection('cashflows');
  CollectionReference<Map<String, dynamic>> get _venues =>
      _db.collection('venues');
  CollectionReference<Map<String, dynamic>> get _ratings =>
      _db.collection('ratings');
  CollectionReference<Map<String, dynamic>> get _partners =>
      _db.collection('partners');
  CollectionReference<Map<String, dynamic>> get _matchResults =>
      _db.collection('matchResults');
  CollectionReference<Map<String, dynamic>> get _chipsTransactions =>
      _db.collection('chipsTransactions');
  CollectionReference<Map<String, dynamic>> get _awards =>
      _db.collection('awards');
  CollectionReference<Map<String, dynamic>> get _redemptions =>
      _db.collection('redemptions');
  CollectionReference<Map<String, dynamic>> get _referrals =>
      _db.collection('referrals');

  // =========================================================================
  // USERS
  // =========================================================================

  Future<UserModel?> getUserById(String id) async {
    return readBreaker.call(() async {
      final doc = await _users.doc(id).get().timeout(_readTimeout);
      if (!doc.exists) return null;
      return UserModel.fromJson({...doc.data()!, 'id': doc.id});
    });
  }

  Future<UserModel?> getUserByPhone(String phone) async {
    return readBreaker.call(() async {
      final snap = await _users
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get()
          .timeout(_readTimeout);
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return UserModel.fromJson({...doc.data(), 'id': doc.id});
    });
  }

  Future<List<UserModel>> getUsers() async {
    return readBreaker.call(() async {
      final snap =
          await _users.limit(_maxQueryResults).get().timeout(_readTimeout);
      return snap.docs
          .map((d) => UserModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setUser(UserModel user) async {
    return writeBreaker.call(() async {
      await _users.doc(user.id).set(user.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> updateUser(UserModel user) async {
    return writeBreaker.call(() async {
      await _users.doc(user.id).update(user.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> removeUser(String userId) async {
    return writeBreaker.call(() async {
      await _users.doc(userId).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // SESSIONS
  // =========================================================================

  Future<List<SessionModel>> getSessions() async {
    return readBreaker.call(() async {
      final snap = await _sessions
          .orderBy('date', descending: true)
          .limit(_maxQueryResults)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => SessionModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Stream<List<SessionModel>> sessionsStream() {
    return _sessions
        .orderBy('date', descending: true)
        .limit(_maxQueryResults)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SessionModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<SessionModel?> getSessionById(String id) async {
    return readBreaker.call(() async {
      final doc = await _sessions.doc(id).get().timeout(_readTimeout);
      if (!doc.exists) return null;
      return SessionModel.fromJson({...doc.data()!, 'id': doc.id});
    });
  }

  Future<void> setSession(SessionModel session) async {
    return writeBreaker.call(() async {
      final data = session.toJson();
      data['confirmedCount'] = 0;
      await _sessions.doc(session.id).set(data).timeout(_writeTimeout);
    });
  }

  Future<void> updateSession(SessionModel session) async {
    return writeBreaker.call(() async {
      await _sessions
          .doc(session.id)
          .update(session.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> removeSession(String sessionId) async {
    return writeBreaker.call(() async {
      await _sessions.doc(sessionId).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // SLOTS
  // =========================================================================

  Future<List<SlotModel>> getAllSlots() async {
    return readBreaker.call(() async {
      final snap =
          await _slots.limit(_maxQueryResults).get().timeout(_readTimeout);
      return snap.docs
          .map((d) => SlotModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<List<SlotModel>> getSlotsForSession(String sessionId) async {
    return readBreaker.call(() async {
      final snap = await _slots
          .where('sessionId', isEqualTo: sessionId)
          .limit(50)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => SlotModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Stream<List<SlotModel>> slotsStreamForSession(String sessionId) {
    return _slots
        .where('sessionId', isEqualTo: sessionId)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SlotModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<SlotModel>> allSlotsStream() {
    return _slots.limit(_maxQueryResults).snapshots().map((snap) => snap.docs
        .map((d) => SlotModel.fromJson({...d.data(), 'id': d.id}))
        .toList());
  }

  Future<SlotModel?> getSlotById(String id) async {
    return readBreaker.call(() async {
      final doc = await _slots.doc(id).get().timeout(_readTimeout);
      if (!doc.exists) return null;
      return SlotModel.fromJson({...doc.data()!, 'id': doc.id});
    });
  }

  Future<List<SlotModel>> getSlotsForUser(String userId) async {
    return readBreaker.call(() async {
      final snap = await _slots
          .where('userId', isEqualTo: userId)
          .limit(_maxQueryResults)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => SlotModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setSlot(SlotModel slot) async {
    return writeBreaker.call(() async {
      await _slots.doc(slot.id).set(slot.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> updateSlot(SlotModel slot) async {
    return writeBreaker.call(() async {
      await _slots.doc(slot.id).update(slot.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> removeSlot(String slotId) async {
    return writeBreaker.call(() async {
      await _slots.doc(slotId).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // PAYMENTS
  // =========================================================================

  Future<List<PaymentModel>> getAllPayments() async {
    return readBreaker.call(() async {
      final snap =
          await _payments.limit(_maxQueryResults).get().timeout(_readTimeout);
      return snap.docs
          .map((d) => PaymentModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<List<PaymentModel>> getPaymentsForSession(String sessionId) async {
    return readBreaker.call(() async {
      final snap = await _payments
          .where('sessionId', isEqualTo: sessionId)
          .limit(50)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => PaymentModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Stream<List<PaymentModel>> allPaymentsStream() {
    return _payments.limit(_maxQueryResults).snapshots().map((snap) => snap.docs
        .map((d) => PaymentModel.fromJson({...d.data(), 'id': d.id}))
        .toList());
  }

  Future<PaymentModel?> getPaymentById(String id) async {
    return readBreaker.call(() async {
      final doc = await _payments.doc(id).get().timeout(_readTimeout);
      if (!doc.exists) return null;
      return PaymentModel.fromJson({...doc.data()!, 'id': doc.id});
    });
  }

  Future<PaymentModel?> getPaymentForSlot(String slotId) async {
    return readBreaker.call(() async {
      final snap = await _payments
          .where('slotId', isEqualTo: slotId)
          .limit(1)
          .get()
          .timeout(_readTimeout);
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return PaymentModel.fromJson({...doc.data(), 'id': doc.id});
    });
  }

  Future<void> setPayment(PaymentModel payment) async {
    return writeBreaker.call(() async {
      await _payments
          .doc(payment.id)
          .set(payment.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> updatePayment(PaymentModel payment) async {
    return writeBreaker.call(() async {
      await _payments
          .doc(payment.id)
          .update(payment.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> removePayment(String paymentId) async {
    return writeBreaker.call(() async {
      await _payments.doc(paymentId).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // CASHFLOWS
  // =========================================================================

  Future<List<CashFlowModel>> getCashFlows() async {
    return readBreaker.call(() async {
      final snap = await _cashflows
          .orderBy('createdAt', descending: true)
          .limit(_maxQueryResults)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => CashFlowModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Stream<List<CashFlowModel>> cashFlowsStream() {
    return _cashflows
        .orderBy('createdAt', descending: true)
        .limit(_maxQueryResults)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CashFlowModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> setCashFlow(CashFlowModel cashflow) async {
    return writeBreaker.call(() async {
      await _cashflows
          .doc(cashflow.id)
          .set(cashflow.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> removeCashFlow(String cashflowId) async {
    return writeBreaker.call(() async {
      await _cashflows.doc(cashflowId).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // VENUES
  // =========================================================================

  Future<List<VenueModel>> getVenues() async {
    return readBreaker.call(() async {
      final snap =
          await _venues.limit(_maxQueryResults).get().timeout(_readTimeout);
      return snap.docs
          .map((d) => VenueModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setVenue(VenueModel venue) async {
    return writeBreaker.call(() async {
      await _venues.doc(venue.id).set(venue.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> updateVenue(VenueModel venue) async {
    return writeBreaker.call(() async {
      await _venues
          .doc(venue.id)
          .update(venue.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> deleteVenue(String venueId) async {
    return writeBreaker.call(() async {
      await _venues.doc(venueId).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // RATINGS
  // =========================================================================

  Future<List<RatingModel>> getRatings() async {
    return readBreaker.call(() async {
      final snap =
          await _ratings.limit(_maxQueryResults).get().timeout(_readTimeout);
      return snap.docs
          .map((d) => RatingModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setRating(RatingModel rating) async {
    return writeBreaker.call(() async {
      await _ratings.doc(rating.id).set(rating.toJson()).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // PARTNERS
  // =========================================================================

  Future<List<PartnerModel>> getPartners() async {
    return readBreaker.call(() async {
      final snap =
          await _partners.limit(_maxQueryResults).get().timeout(_readTimeout);
      return snap.docs
          .map((d) => PartnerModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setPartner(PartnerModel partner) async {
    return writeBreaker.call(() async {
      await _partners
          .doc(partner.id)
          .set(partner.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> updatePartner(PartnerModel partner) async {
    return writeBreaker.call(() async {
      await _partners
          .doc(partner.id)
          .update(partner.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> deletePartner(String id) async {
    return writeBreaker.call(() async {
      await _partners.doc(id).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // MATCH RESULTS
  // =========================================================================

  Future<List<MatchResultModel>> getMatchResults() async {
    return readBreaker.call(() async {
      final snap = await _matchResults
          .limit(_maxQueryResults)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => MatchResultModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setMatchResult(MatchResultModel result) async {
    return writeBreaker.call(() async {
      await _matchResults
          .doc(result.id)
          .set(result.toJson())
          .timeout(_writeTimeout);
    });
  }

  Future<void> deleteMatchResult(String id) async {
    return writeBreaker.call(() async {
      await _matchResults.doc(id).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // CHIPS TRANSACTIONS
  // =========================================================================

  Future<List<ChipsTransactionModel>> getChipsTransactions() async {
    return readBreaker.call(() async {
      final snap = await _chipsTransactions
          .orderBy('createdAt', descending: true)
          .limit(_maxQueryResults)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => ChipsTransactionModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setChipsTransaction(ChipsTransactionModel txn) async {
    return writeBreaker.call(() async {
      await _chipsTransactions
          .doc(txn.id)
          .set(txn.toJson())
          .timeout(_writeTimeout);
    });
  }

  /// Atomic chips award: read user balance inside transaction → compute new
  /// balance → write transaction + update user balance. Prevents TOCTOU race
  /// where two concurrent awards could overwrite each other's balance.
  Future<void> awardChipsTransaction({
    required ChipsTransactionModel txn,
    required String userId,
    required int amount,
  }) async {
    return writeBreaker.call(() async {
      await _db.runTransaction((transaction) async {
        // Read current balance inside the transaction for atomicity
        final userDoc = await transaction.get(_users.doc(userId));
        final currentBalance =
            (userDoc.data()?['chipsBalance'] as int?) ?? 0;
        final newBalance = currentBalance + amount;

        transaction.set(_chipsTransactions.doc(txn.id), txn.toJson());
        transaction.update(
            _users.doc(userId), {'chipsBalance': newBalance});
      }).timeout(_writeTimeout);
    });
  }

  /// Atomic array union — uses FieldValue.arrayUnion for safe concurrent merges.
  Future<void> atomicArrayUnion({
    required String collection,
    required String docId,
    required String field,
    required List<String> values,
  }) async {
    return writeBreaker.call(() async {
      await _db
          .collection(collection)
          .doc(docId)
          .update({field: FieldValue.arrayUnion(values)}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // AWARDS
  // =========================================================================

  Future<List<AwardModel>> getAwards() async {
    return readBreaker.call(() async {
      final snap = await _awards
          .orderBy('awardedAt', descending: true)
          .limit(_maxQueryResults)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => AwardModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setAward(AwardModel award) async {
    return writeBreaker.call(() async {
      await _awards.doc(award.id).set(award.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> deleteAward(String id) async {
    return writeBreaker.call(() async {
      await _awards.doc(id).update(
          {'deletedAt': DateTime.now().toIso8601String()}).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // REDEMPTIONS
  // =========================================================================

  Future<List<RedemptionModel>> getRedemptions() async {
    return readBreaker.call(() async {
      final snap = await _redemptions
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => RedemptionModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setRedemption(RedemptionModel r) async {
    return writeBreaker.call(() async {
      await _redemptions.doc(r.id).set(r.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> updateRedemption(RedemptionModel r) async {
    return writeBreaker.call(() async {
      await _redemptions.doc(r.id).set(r.toJson()).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // REFERRALS
  // =========================================================================

  Future<List<ReferralModel>> getReferrals() async {
    return readBreaker.call(() async {
      final snap = await _referrals
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(_readTimeout);
      return snap.docs
          .map((d) => ReferralModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> setReferral(ReferralModel r) async {
    return writeBreaker.call(() async {
      await _referrals.doc(r.id).set(r.toJson()).timeout(_writeTimeout);
    });
  }

  Future<void> updateReferral(ReferralModel r) async {
    return writeBreaker.call(() async {
      await _referrals.doc(r.id).set(r.toJson()).timeout(_writeTimeout);
    });
  }

  // =========================================================================
  // FIRESTORE TRANSACTIONS: Atomic operations for concurrency safety
  // =========================================================================

  /// Atomically join a session. Uses a denormalized confirmedCount on the
  /// session document to prevent overbooking. Returns the created SlotModel.
  Future<SlotModel> joinSessionTransaction({
    required String sessionId,
    required String userId,
    required String userName,
    required String newSlotId,
  }) async {
    return _traced('firestore_join_session', () async {
    return writeBreaker.call(() async {
    // Guard: user already joined? (non-transactional pre-check)
    final existing = await _slots
        .where('sessionId', isEqualTo: sessionId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const ConflictException('Kamu sudah terdaftar di sesi ini.');
    }

    return _db.runTransaction<SlotModel>((txn) async {
      final sessionSnap = await txn.get(_sessions.doc(sessionId));
      if (!sessionSnap.exists) {
        throw const ConflictException('Sesi tidak ditemukan.');
      }

      final data = sessionSnap.data()!;
      final maxPlayers = data['maxPlayers'] as int;
      final status = data['status'] as String;
      final confirmedCount = (data['confirmedCount'] as int?) ?? 0;

      if (status == 'locked' ||
          status == 'completed' ||
          status == 'cancelled') {
        throw const ConflictException('Sesi sudah ditutup.');
      }

      final isFull = confirmedCount >= maxPlayers;
      final now = DateTime.now();

      final slot = SlotModel(
        id: newSlotId,
        sessionId: sessionId,
        userId: userId,
        userName: userName,
        status: isFull ? SlotStatus.waitlist : SlotStatus.confirmed,
        joinedAt: now,
        confirmedAt: isFull ? null : now,
      );

      txn.set(_slots.doc(newSlotId), slot.toJson());

      if (!isFull) {
        final newCount = confirmedCount + 1;
        final updates = <String, dynamic>{'confirmedCount': newCount};
        if (newCount >= maxPlayers) {
          updates['status'] = SessionStatus.full.name;
        }
        txn.update(_sessions.doc(sessionId), updates);
      }

      return slot;
    }).timeout(_writeTimeout);
    });
    });
  }

  /// Atomically leave a session. Decrements confirmedCount and promotes
  /// the earliest waitlisted player if applicable.
  Future<void> leaveSessionTransaction({
    required String sessionId,
    required List<String> slotIdsToRemove,
    required List<String> paymentIdsToRemove,
    required bool wasConfirmed,
    String? waitlistSlotIdToPromote,
  }) async {
    return _traced('firestore_leave_session', () async {
    return writeBreaker.call(() async {
    await _db.runTransaction((txn) async {
      final sessionSnap = await txn.get(_sessions.doc(sessionId));
      if (!sessionSnap.exists) return;

      // Soft-delete slots and payments
      final now = DateTime.now().toIso8601String();
      for (final id in slotIdsToRemove) {
        txn.update(_slots.doc(id), {'deletedAt': now});
      }
      for (final id in paymentIdsToRemove) {
        txn.update(_payments.doc(id), {'deletedAt': now});
      }

      if (wasConfirmed) {
        final data = sessionSnap.data()!;
        final maxPlayers = data['maxPlayers'] as int;
        var newCount = ((data['confirmedCount'] as int?) ?? 0) - 1;
        if (newCount < 0) newCount = 0;

        if (waitlistSlotIdToPromote != null) {
          txn.update(_slots.doc(waitlistSlotIdToPromote), {
            'status': SlotStatus.confirmed.name,
            'confirmedAt': DateTime.now().toIso8601String(),
          });
          newCount += 1;
        }

        final updates = <String, dynamic>{'confirmedCount': newCount};
        if (newCount < maxPlayers) {
          updates['status'] = SessionStatus.open.name;
        }
        txn.update(_sessions.doc(sessionId), updates);
      }
    }).timeout(_writeTimeout);
    });
    });
  }

  /// Atomically verify a payment, update slot to paid, and create a
  /// cashflow income entry — all in one transaction.
  Future<void> verifyPaymentTransaction({
    required String paymentId,
    required String verifierId,
    required String slotId,
    required CashFlowModel cashflowEntry,
  }) async {
    return _traced('firestore_verify_payment', () async {
    return writeBreaker.call(() async {
    await _db.runTransaction((txn) async {
      final paySnap = await txn.get(_payments.doc(paymentId));
      if (!paySnap.exists) {
        throw const ConflictException('Pembayaran tidak ditemukan.');
      }
      if (paySnap.data()!['status'] == PaymentStatus.verified.name) {
        throw const ConflictException('Pembayaran sudah diverifikasi.');
      }

      final now = DateTime.now();

      txn.update(_payments.doc(paymentId), {
        'status': PaymentStatus.verified.name,
        'verifiedBy': verifierId,
        'verifiedAt': now.toIso8601String(),
      });

      txn.update(_slots.doc(slotId), {
        'status': SlotStatus.paid.name,
      });

      txn.set(_cashflows.doc(cashflowEntry.id), cashflowEntry.toJson());
    }).timeout(_writeTimeout);
    });
    });
  }

  /// Migration: ensure all session docs have a confirmedCount field.
  /// Called once during DataService.initialize().
  Future<void> syncConfirmedCounts() async {
    final sessionsSnap = await _sessions.get();
    final batch = _db.batch();
    var updateCount = 0;

    for (final doc in sessionsSnap.docs) {
      if (doc.data()['confirmedCount'] == null) {
        final slotsSnap =
            await _slots.where('sessionId', isEqualTo: doc.id).get();
        final count = slotsSnap.docs.where((d) {
          final s = d.data()['status'] as String;
          return s == 'confirmed' || s == 'paid' || s == 'locked';
        }).length;
        batch.update(_sessions.doc(doc.id), {'confirmedCount': count});
        updateCount++;
      }
    }

    if (updateCount > 0) {
      await batch.commit();
      AppLogger.i('FirestoreService', 'Synced confirmedCount for $updateCount sessions');
    }
  }

  // =========================================================================
  // SEED: One-time seed check — writes demo data if collection is empty
  // =========================================================================

  Future<void> seedIfEmpty() async {
    try {
      // Check both users AND slots to detect partial/failed seeds
      final usersSnap = await _users.limit(1).get();
      final slotsSnap = await _slots.limit(1).get();
      final venuesSnap = await _venues.limit(1).get();

      final hasUsers = usersSnap.docs.isNotEmpty;
      final hasSlots = slotsSnap.docs.isNotEmpty;
      final hasVenues = venuesSnap.docs.isNotEmpty;

      if (hasUsers && hasSlots && hasVenues) {
        AppLogger.d('FirestoreService', 'Already seeded — skipping');
        return;
      }

      if (hasUsers && !hasSlots) {
        AppLogger.w('FirestoreService', 'Partial seed detected (users exist but slots missing) — reseeding');
      }

      AppLogger.i('FirestoreService', 'Seeding Firestore with demo data...');
      final now = DateTime.now();

      // Build all seed data
      final users = _buildSeedUsers(now);
      final sessions = _buildSeedSessions(users, now);
      final slots = _buildSeedSlots(users, sessions, now);
      final payments = _buildSeedPayments(users, sessions, slots, now);
      final cashflows = _buildSeedCashFlows(users, sessions, now);
      final partners = _buildSeedPartners(now);
      final matchResults = _buildSeedMatchResults(users, now);
      final venues = _buildSeedVenues();
      final ratings = _buildSeedRatings(users, now);

      // Use two batches to stay safely under Firestore 500-write limit
      final batch1 = _db.batch();
      for (final u in users) {
        batch1.set(_users.doc(u.id), u.toJson());
      }
      for (final s in sessions) {
        batch1.set(_sessions.doc(s.id), s.toJson());
      }
      for (final s in slots) {
        batch1.set(_slots.doc(s.id), s.toJson());
      }
      for (final p in payments) {
        batch1.set(_payments.doc(p.id), p.toJson());
      }
      await batch1.commit();

      final batch2 = _db.batch();
      for (final c in cashflows) {
        batch2.set(_cashflows.doc(c.id), c.toJson());
      }
      for (final p in partners) {
        batch2.set(_partners.doc(p.id), p.toJson());
      }
      for (final m in matchResults) {
        batch2.set(_matchResults.doc(m.id), m.toJson());
      }
      for (final v in venues) {
        batch2.set(_venues.doc(v.id), v.toJson());
      }
      for (final r in ratings) {
        batch2.set(_ratings.doc(r.id), r.toJson());
      }
      await batch2.commit();

      AppLogger.i('FirestoreService', 'Seeded: ${users.length} users, '
          '${sessions.length} sessions, ${slots.length} slots, '
          '${payments.length} payments, ${cashflows.length} cashflows, '
          '${partners.length} partners, ${matchResults.length} matchResults, '
          '${venues.length} venues, ${ratings.length} ratings');
    } catch (e) {
      AppLogger.e('FirestoreService', 'Seed failed', error: e);
    }
  }

  // ---- Seed builders (same data as old DataService._seedData) ----

  List<UserModel> _buildSeedUsers(DateTime now) {
    return [
      UserModel(id: 'user-reza', name: 'Reza Rahadian', phone: '08119990001', role: UserRole.superAdmin, createdAt: now.subtract(const Duration(days: 180)), nickname: 'Reza', bio: 'Founder Daddies Padel Community. Suka ngajak main & ngumpul bareng.'),
      UserModel(id: 'user-hendy', name: 'Hendy Wijaya', phone: '08119990002', role: UserRole.mimin, createdAt: now.subtract(const Duration(days: 170)), nickname: 'Hendy', bio: 'Mimin andalan yang selalu rajin booking court. Backhand enthusiast.'),
      UserModel(id: 'user-bima', name: 'Bima Sakti', phone: '08119990003', role: UserRole.mimin, createdAt: now.subtract(const Duration(days: 165)), nickname: 'Bima', bio: 'Mimin night session. Kalau bola mental, dia yang paling semangat.'),
      UserModel(id: 'user-fajar', name: 'Fajar Nugroho', phone: '08119990004', role: UserRole.bendahara, createdAt: now.subtract(const Duration(days: 160)), nickname: 'Fajar', bio: 'Bendahara yang selalu tepat hitung. Juga jago lob!'),
      UserModel(id: 'user-arif', name: 'Arif Budiman', phone: '08129990005', role: UserRole.member, createdAt: now.subtract(const Duration(days: 120)), nickname: 'Arif', bio: 'Newbie yang progresnya cepat. Suka drill pagi-pagi.'),
      UserModel(id: 'user-denny', name: 'Denny Pratama', phone: '08139990006', role: UserRole.member, createdAt: now.subtract(const Duration(days: 110)), nickname: 'Den', bio: 'Pemain all-round. Bisa main depan, bisa main belakang.'),
      UserModel(id: 'user-gilang', name: 'Gilang Ramadhan', phone: '08159990007', role: UserRole.member, createdAt: now.subtract(const Duration(days: 100)), nickname: 'Gilang', bio: 'Smash keras, tapi kadang keluar. Semangat terus!'),
      UserModel(id: 'user-raka', name: 'Raka Aditya', phone: '08179990008', role: UserRole.member, createdAt: now.subtract(const Duration(days: 95)), nickname: 'Raka', bio: 'Si strategis yang suka main placement. Tenang tapi mematikan.'),
      UserModel(id: 'user-tommy', name: 'Tommy Hartono', phone: '08189990009', role: UserRole.member, createdAt: now.subtract(const Duration(days: 80)), nickname: 'Tom', bio: 'Tembok pertahanan. Susah dilewati kalau jaga belakang.'),
      UserModel(id: 'user-andre', name: 'Andre Kusuma', phone: '08199990010', role: UserRole.member, createdAt: now.subtract(const Duration(days: 70)), nickname: 'Andre', bio: 'Spesialis net play. Volley-nya tajam dan akurat.'),
      UserModel(id: 'user-bayu', name: 'Bayu Pratomo', phone: '08211990011', role: UserRole.member, createdAt: now.subtract(const Duration(days: 45)), nickname: 'Bayu', bio: 'Morning person yang suka padel sebelum ngantor.'),
      UserModel(id: 'user-cahyo', name: 'Cahyo Wibowo', phone: '08221990012', role: UserRole.member, createdAt: now.subtract(const Duration(days: 30)), nickname: 'Cah', bio: 'Weekend warrior. Cuma bisa main Sabtu-Minggu tapi serius!'),
    ];
  }

  List<SessionModel> _buildSeedSessions(List<UserModel> users, DateTime now) {
    final reza = users[0], hendy = users[1], bima = users[2];
    return [
      SessionModel(id: 'session-1', miminId: hendy.id, miminName: hendy.name, title: 'Mabar Sabtu Sore', venue: 'Genesis Padel', date: now.subtract(const Duration(days: 28)), timeStart: '16:00', timeEnd: '18:00', maxPlayers: 8, pricePerPlayer: 150000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 32))),
      SessionModel(id: 'session-2', miminId: bima.id, miminName: bima.name, title: 'Rabu Siang Chill', venue: 'Padel Haus BSD', date: now.subtract(const Duration(days: 21)), timeStart: '12:00', timeEnd: '14:00', maxPlayers: 8, pricePerPlayer: 125000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 25))),
      SessionModel(id: 'session-3', miminId: hendy.id, miminName: hendy.name, title: 'Friday Night Smash', venue: 'The Padel Club PIK', date: now.subtract(const Duration(days: 14)), timeStart: '19:00', timeEnd: '21:00', maxPlayers: 8, pricePerPlayer: 200000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 18))),
      SessionModel(id: 'session-4', miminId: bima.id, miminName: bima.name, title: 'Weekend Warriors', venue: 'Genesis Padel', date: now.subtract(const Duration(days: 7)), timeStart: '08:00', timeEnd: '10:00', maxPlayers: 8, pricePerPlayer: 150000, status: SessionStatus.completed, createdAt: now.subtract(const Duration(days: 10))),
      SessionModel(id: 'session-5', miminId: bima.id, miminName: bima.name, title: 'Jumat Night Session', venue: 'Padel Haus BSD', date: now.add(const Duration(days: 2)), timeStart: '19:00', timeEnd: '21:00', maxPlayers: 8, pricePerPlayer: 175000, status: SessionStatus.locked, createdAt: now.subtract(const Duration(days: 5))),
      SessionModel(id: 'session-6', miminId: hendy.id, miminName: hendy.name, title: 'Sunday Funday', venue: 'The Padel Club PIK', date: now.add(const Duration(days: 4)), timeStart: '09:00', timeEnd: '11:00', maxPlayers: 8, pricePerPlayer: 200000, status: SessionStatus.open, createdAt: now.subtract(const Duration(days: 3))),
      SessionModel(id: 'session-7', miminId: hendy.id, miminName: hendy.name, title: 'Senin Pagi Semangat', venue: 'Padel Haus BSD', date: now.add(const Duration(days: 8)), timeStart: '07:00', timeEnd: '09:00', maxPlayers: 8, pricePerPlayer: 125000, status: SessionStatus.open, createdAt: now.subtract(const Duration(days: 1))),
      SessionModel(id: 'session-8', miminId: reza.id, miminName: reza.name, title: 'Daddies Cup Mini Tournament', venue: 'Genesis Padel', date: now.add(const Duration(days: 15)), timeStart: '08:00', timeEnd: '12:00', maxPlayers: 16, pricePerPlayer: 250000, status: SessionStatus.draft, createdAt: now),
    ];
  }

  List<SlotModel> _buildSeedSlots(List<UserModel> users, List<SessionModel> sessions, DateTime now) {
    final reza = users[0], hendy = users[1], bima = users[2], fajar = users[3];
    final arif = users[4], denny = users[5], gilang = users[6], raka = users[7];
    final tommy = users[8], andre = users[9], bayu = users[10], cahyo = users[11];

    return [
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
    ];
  }

  List<PaymentModel> _buildSeedPayments(List<UserModel> users, List<SessionModel> sessions, List<SlotModel> slots, DateTime now) {
    final reza = users[0], hendy = users[1], bima = users[2], fajar = users[3];
    final arif = users[4], denny = users[5], gilang = users[6], raka = users[7];
    final tommy = users[8], andre = users[9], bayu = users[10], cahyo = users[11];

    return [
      // Session 1: 8 verified (completed, 8 x Rp150.000)
      PaymentModel(id: 'pay-1a', slotId: 'slot-1a', sessionId: 'session-1', userId: arif.id, userName: arif.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      PaymentModel(id: 'pay-1b', slotId: 'slot-1b', sessionId: 'session-1', userId: denny.id, userName: denny.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      PaymentModel(id: 'pay-1c', slotId: 'slot-1c', sessionId: 'session-1', userId: gilang.id, userName: gilang.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      PaymentModel(id: 'pay-1d', slotId: 'slot-1d', sessionId: 'session-1', userId: raka.id, userName: raka.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      PaymentModel(id: 'pay-1e', slotId: 'slot-1e', sessionId: 'session-1', userId: hendy.id, userName: hendy.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      PaymentModel(id: 'pay-1f', slotId: 'slot-1f', sessionId: 'session-1', userId: bima.id, userName: bima.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      PaymentModel(id: 'pay-1g', slotId: 'slot-1g', sessionId: 'session-1', userId: fajar.id, userName: fajar.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: hendy.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      PaymentModel(id: 'pay-1h', slotId: 'slot-1h', sessionId: 'session-1', userId: reza.id, userName: reza.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 29)), createdAt: now.subtract(const Duration(days: 29))),
      // Session 2: 6 verified (completed, 6 x Rp125.000)
      PaymentModel(id: 'pay-2a', slotId: 'slot-2a', sessionId: 'session-2', userId: denny.id, userName: denny.name, amount: 125000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 22)), createdAt: now.subtract(const Duration(days: 22))),
      PaymentModel(id: 'pay-2b', slotId: 'slot-2b', sessionId: 'session-2', userId: gilang.id, userName: gilang.name, amount: 125000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 22)), createdAt: now.subtract(const Duration(days: 22))),
      PaymentModel(id: 'pay-2c', slotId: 'slot-2c', sessionId: 'session-2', userId: bima.id, userName: bima.name, amount: 125000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 22)), createdAt: now.subtract(const Duration(days: 22))),
      PaymentModel(id: 'pay-2d', slotId: 'slot-2d', sessionId: 'session-2', userId: tommy.id, userName: tommy.name, amount: 125000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 22)), createdAt: now.subtract(const Duration(days: 22))),
      PaymentModel(id: 'pay-2e', slotId: 'slot-2e', sessionId: 'session-2', userId: andre.id, userName: andre.name, amount: 125000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 22)), createdAt: now.subtract(const Duration(days: 22))),
      PaymentModel(id: 'pay-2f', slotId: 'slot-2f', sessionId: 'session-2', userId: fajar.id, userName: fajar.name, amount: 125000, status: PaymentStatus.verified, verifiedBy: bima.name, verifiedAt: now.subtract(const Duration(days: 22)), createdAt: now.subtract(const Duration(days: 22))),
      // Session 3: 8 verified (completed, 8 x Rp200.000)
      PaymentModel(id: 'pay-3a', slotId: 'slot-3a', sessionId: 'session-3', userId: arif.id, userName: arif.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 15)), createdAt: now.subtract(const Duration(days: 15))),
      PaymentModel(id: 'pay-3b', slotId: 'slot-3b', sessionId: 'session-3', userId: raka.id, userName: raka.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 15)), createdAt: now.subtract(const Duration(days: 15))),
      PaymentModel(id: 'pay-3c', slotId: 'slot-3c', sessionId: 'session-3', userId: hendy.id, userName: hendy.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 15)), createdAt: now.subtract(const Duration(days: 15))),
      PaymentModel(id: 'pay-3d', slotId: 'slot-3d', sessionId: 'session-3', userId: tommy.id, userName: tommy.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 15)), createdAt: now.subtract(const Duration(days: 15))),
      PaymentModel(id: 'pay-3e', slotId: 'slot-3e', sessionId: 'session-3', userId: andre.id, userName: andre.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 15)), createdAt: now.subtract(const Duration(days: 15))),
      PaymentModel(id: 'pay-3f', slotId: 'slot-3f', sessionId: 'session-3', userId: denny.id, userName: denny.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 14)), createdAt: now.subtract(const Duration(days: 15))),
      PaymentModel(id: 'pay-3g', slotId: 'slot-3g', sessionId: 'session-3', userId: gilang.id, userName: gilang.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 14)), createdAt: now.subtract(const Duration(days: 14))),
      PaymentModel(id: 'pay-3h', slotId: 'slot-3h', sessionId: 'session-3', userId: fajar.id, userName: fajar.name, amount: 200000, status: PaymentStatus.verified, verifiedBy: hendy.name, verifiedAt: now.subtract(const Duration(days: 14)), createdAt: now.subtract(const Duration(days: 14))),
      // Session 4: 7 verified (completed, 7 x Rp150.000)
      PaymentModel(id: 'pay-4a', slotId: 'slot-4a', sessionId: 'session-4', userId: arif.id, userName: arif.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
      PaymentModel(id: 'pay-4b', slotId: 'slot-4b', sessionId: 'session-4', userId: denny.id, userName: denny.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
      PaymentModel(id: 'pay-4c', slotId: 'slot-4c', sessionId: 'session-4', userId: raka.id, userName: raka.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
      PaymentModel(id: 'pay-4d', slotId: 'slot-4d', sessionId: 'session-4', userId: bima.id, userName: bima.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
      PaymentModel(id: 'pay-4e', slotId: 'slot-4e', sessionId: 'session-4', userId: bayu.id, userName: bayu.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
      PaymentModel(id: 'pay-4f', slotId: 'slot-4f', sessionId: 'session-4', userId: cahyo.id, userName: cahyo.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
      PaymentModel(id: 'pay-4g', slotId: 'slot-4g', sessionId: 'session-4', userId: tommy.id, userName: tommy.name, amount: 150000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
      // Session 5: 6 verified + 1 pending (locked upcoming)
      PaymentModel(id: 'pay-5a', slotId: 'slot-5a', sessionId: 'session-5', userId: arif.id, userName: arif.name, amount: 175000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 2)), createdAt: now.subtract(const Duration(days: 3))),
      PaymentModel(id: 'pay-5b', slotId: 'slot-5b', sessionId: 'session-5', userId: denny.id, userName: denny.name, amount: 175000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 2)), createdAt: now.subtract(const Duration(days: 3))),
      PaymentModel(id: 'pay-5c', slotId: 'slot-5c', sessionId: 'session-5', userId: gilang.id, userName: gilang.name, amount: 175000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 2)), createdAt: now.subtract(const Duration(days: 3))),
      PaymentModel(id: 'pay-5d', slotId: 'slot-5d', sessionId: 'session-5', userId: raka.id, userName: raka.name, amount: 175000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 1)), createdAt: now.subtract(const Duration(days: 2))),
      PaymentModel(id: 'pay-5e', slotId: 'slot-5e', sessionId: 'session-5', userId: bima.id, userName: bima.name, amount: 175000, status: PaymentStatus.verified, verifiedBy: fajar.name, verifiedAt: now.subtract(const Duration(days: 2)), createdAt: now.subtract(const Duration(days: 3))),
      PaymentModel(id: 'pay-5f', slotId: 'slot-5f', sessionId: 'session-5', userId: fajar.id, userName: fajar.name, amount: 175000, status: PaymentStatus.verified, verifiedBy: bima.name, verifiedAt: now.subtract(const Duration(days: 1)), createdAt: now.subtract(const Duration(days: 2))),
      PaymentModel(id: 'pay-5g', slotId: 'slot-5g', sessionId: 'session-5', userId: hendy.id, userName: hendy.name, amount: 175000, status: PaymentStatus.pending, createdAt: now.subtract(const Duration(days: 1))),
    ];
  }

  List<CashFlowModel> _buildSeedCashFlows(List<UserModel> users, List<SessionModel> sessions, DateTime now) {
    final fajar = users[3];

    return [
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
    ];
  }

  List<PartnerModel> _buildSeedPartners(DateTime now) {
    return [
      PartnerModel(id: 'partner-genesis', name: 'Genesis Padel', category: 'Venue', discountPercent: 10, discountDescription: 'Diskon 10% sewa lapangan untuk anggota Daddies', address: 'Jl. Jalur Sutera Barat No.15, Alam Sutera', phone: '021-29880123', isActive: true, createdAt: now.subtract(const Duration(days: 90))),
      PartnerModel(id: 'partner-physio', name: 'ProFit Physiotherapy', category: 'Kesehatan', discountPercent: 15, discountDescription: 'Diskon 15% fisioterapi & sport massage', address: 'Ruko BSD Junction Blok A12', phone: '0812-3456-7890', isActive: true, createdAt: now.subtract(const Duration(days: 60))),
      PartnerModel(id: 'partner-racket', name: 'Padel Store Indonesia', category: 'Equipment', discountPercent: 10, discountDescription: 'Diskon 10% semua raket & aksesoris padel', address: 'Mall Alam Sutera Lt. 2', phone: '0857-1234-5678', isActive: true, createdAt: now.subtract(const Duration(days: 45))),
      PartnerModel(id: 'partner-food', name: 'Warung Sehat BSD', category: 'F&B', discountPercent: 20, discountDescription: 'Diskon 20% menu healthy bowl & smoothie post-game', address: 'Jl. BSD Raya Utama No.88', phone: '0821-9876-5432', isActive: true, createdAt: now.subtract(const Duration(days: 30))),
    ];
  }

  List<MatchResultModel> _buildSeedMatchResults(List<UserModel> users, DateTime now) {
    final hendy = users[1], bima = users[2], fajar = users[3];
    final arif = users[4], denny = users[5], gilang = users[6], raka = users[7];
    final tommy = users[8], andre = users[9], bayu = users[10], cahyo = users[11];
    final reza = users[0];

    return [
      MatchResultModel(id: 'mr-1a', sessionId: 'session-1', round: 1, team1PlayerIds: [arif.id, raka.id], team1PlayerNames: [arif.name, raka.name], team2PlayerIds: [hendy.id, denny.id], team2PlayerNames: [hendy.name, denny.name], team1Score: 6, team2Score: 4, createdAt: now.subtract(const Duration(days: 28))),
      MatchResultModel(id: 'mr-1b', sessionId: 'session-1', round: 2, team1PlayerIds: [bima.id, fajar.id], team1PlayerNames: [bima.name, fajar.name], team2PlayerIds: [gilang.id, reza.id], team2PlayerNames: [gilang.name, reza.name], team1Score: 5, team2Score: 5, createdAt: now.subtract(const Duration(days: 28))),
      MatchResultModel(id: 'mr-1c', sessionId: 'session-1', round: 3, team1PlayerIds: [arif.id, bima.id], team1PlayerNames: [arif.name, bima.name], team2PlayerIds: [raka.id, fajar.id], team2PlayerNames: [raka.name, fajar.name], team1Score: 7, team2Score: 3, createdAt: now.subtract(const Duration(days: 28))),
      MatchResultModel(id: 'mr-3a', sessionId: 'session-3', round: 1, team1PlayerIds: [arif.id, andre.id], team1PlayerNames: [arif.name, andre.name], team2PlayerIds: [raka.id, tommy.id], team2PlayerNames: [raka.name, tommy.name], team1Score: 6, team2Score: 6, createdAt: now.subtract(const Duration(days: 14))),
      MatchResultModel(id: 'mr-3b', sessionId: 'session-3', round: 2, team1PlayerIds: [hendy.id, raka.id], team1PlayerNames: [hendy.name, raka.name], team2PlayerIds: [arif.id, gilang.id], team2PlayerNames: [arif.name, gilang.name], team1Score: 7, team2Score: 4, createdAt: now.subtract(const Duration(days: 14))),
      MatchResultModel(id: 'mr-4a', sessionId: 'session-4', round: 1, team1PlayerIds: [denny.id, raka.id], team1PlayerNames: [denny.name, raka.name], team2PlayerIds: [arif.id, tommy.id], team2PlayerNames: [arif.name, tommy.name], team1Score: 6, team2Score: 5, createdAt: now.subtract(const Duration(days: 7))),
      MatchResultModel(id: 'mr-4b', sessionId: 'session-4', round: 2, team1PlayerIds: [bima.id, bayu.id], team1PlayerNames: [bima.name, bayu.name], team2PlayerIds: [denny.id, cahyo.id], team2PlayerNames: [denny.name, cahyo.name], team1Score: 4, team2Score: 6, createdAt: now.subtract(const Duration(days: 7))),
    ];
  }

  List<VenueModel> _buildSeedVenues() {
    return const [
      VenueModel(
        id: 'venue-genesis',
        name: 'Genesis Padel',
        address: 'Jl. Jalur Sutera Barat No.15, Alam Sutera, Tangerang Selatan',
        bio: 'Genesis Padel adalah venue padel premium pertama di kawasan Alam Sutera.',
        phone: '021-29880123',
        facilities: ['Indoor Courts', 'Café & Lounge', 'Parkir Luas', 'Shower', 'Free WiFi', 'Rental Raket'],
        courtCount: 4,
        openHours: '07:00 - 23:00',
      ),
      VenueModel(
        id: 'venue-haus',
        name: 'Padel Haus BSD',
        address: 'Jl. Edutown BSD City, Tangerang Selatan',
        bio: 'Padel Haus BSD menawarkan fasilitas lengkap untuk pemain padel semua level.',
        phone: '021-55880456',
        facilities: ['Indoor Courts', 'Café & Lounge', 'Parkir Luas', 'Shower', 'Free WiFi', 'Rental Raket'],
        courtCount: 3,
        openHours: '07:00 - 22:00',
      ),
      VenueModel(
        id: 'venue-pik',
        name: 'The Padel Club PIK',
        address: 'Jl. Pantai Indah Utara 2, Pantai Indah Kapuk, Jakarta Utara',
        bio: 'The Padel Club PIK adalah destinasi padel eksklusif di kawasan PIK.',
        phone: '021-66601234',
        facilities: ['Semi-Outdoor Courts', 'Restaurant', 'Valet Parking', 'Shower & Locker', 'Pro Shop', 'Kids Area'],
        courtCount: 5,
        openHours: '06:00 - 22:00',
      ),
    ];
  }

  List<RatingModel> _buildSeedRatings(List<UserModel> users, DateTime now) {
    final reza = users[0], hendy = users[1], bima = users[2];
    final arif = users[4], denny = users[5], raka = users[7];
    final tommy = users[8], andre = users[9], bayu = users[10];

    return [
      RatingModel(id: 'rat-01', sessionId: 'session-1', fromUserId: arif.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-02', sessionId: 'session-1', fromUserId: arif.id, toUserId: hendy.id, toUserName: hendy.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-03', sessionId: 'session-1', fromUserId: arif.id, toUserId: denny.id, toUserName: denny.name, rating: 4, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-04', sessionId: 'session-1', fromUserId: raka.id, toUserId: arif.id, toUserName: arif.name, rating: 4, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-05', sessionId: 'session-1', fromUserId: raka.id, toUserId: hendy.id, toUserName: hendy.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-06', sessionId: 'session-1', fromUserId: raka.id, toUserId: reza.id, toUserName: reza.name, rating: 5, createdAt: now.subtract(const Duration(days: 27))),
      RatingModel(id: 'rat-07', sessionId: 'session-3', fromUserId: hendy.id, toUserId: arif.id, toUserName: arif.name, rating: 4, createdAt: now.subtract(const Duration(days: 13))),
      RatingModel(id: 'rat-08', sessionId: 'session-3', fromUserId: hendy.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 13))),
      RatingModel(id: 'rat-09', sessionId: 'session-3', fromUserId: hendy.id, toUserId: andre.id, toUserName: andre.name, rating: 5, createdAt: now.subtract(const Duration(days: 13))),
      RatingModel(id: 'rat-10', sessionId: 'session-3', fromUserId: hendy.id, toUserId: tommy.id, toUserName: tommy.name, rating: 4, createdAt: now.subtract(const Duration(days: 13))),
      RatingModel(id: 'rat-11', sessionId: 'session-4', fromUserId: bima.id, toUserId: arif.id, toUserName: arif.name, rating: 3, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-12', sessionId: 'session-4', fromUserId: bima.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-13', sessionId: 'session-4', fromUserId: bima.id, toUserId: tommy.id, toUserName: tommy.name, rating: 4, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-14', sessionId: 'session-4', fromUserId: bima.id, toUserId: bayu.id, toUserName: bayu.name, rating: 3, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-15', sessionId: 'session-4', fromUserId: denny.id, toUserId: arif.id, toUserName: arif.name, rating: 4, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-16', sessionId: 'session-4', fromUserId: denny.id, toUserId: raka.id, toUserName: raka.name, rating: 5, createdAt: now.subtract(const Duration(days: 6))),
      RatingModel(id: 'rat-17', sessionId: 'session-4', fromUserId: denny.id, toUserId: bima.id, toUserName: bima.name, rating: 4, createdAt: now.subtract(const Duration(days: 6))),
    ];
  }
}
