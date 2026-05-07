import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:daddies_app/core/services/app_logger.dart';

/// Service for uploading and managing files in Firebase Storage.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a payment proof image and return the download URL.
  ///
  /// Path: `payment_proofs/{sessionId}/{userId}_{timestamp}.jpg`
  Future<String> uploadPaymentProof({
    required File file,
    required String sessionId,
    required String userId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'payment_proofs/$sessionId/${userId}_$timestamp.jpg';
    final ref = _storage.ref().child(path);

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    AppLogger.i('StorageService', 'Uploaded $path');
    return downloadUrl;
  }

  /// Upload an avatar image and return the download URL.
  ///
  /// Path: `avatars/{userId}_{timestamp}.jpg`
  Future<String> uploadAvatar({
    required File file,
    required String userId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'avatars/${userId}_$timestamp.jpg';
    final ref = _storage.ref().child(path);

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    AppLogger.i('StorageService', 'Uploaded avatar $path');
    return downloadUrl;
  }

  /// Delete a file from Storage by its download URL.
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      AppLogger.w('StorageService', 'deleteByUrl failed', error: e);
    }
  }
}
