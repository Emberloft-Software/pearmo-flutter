import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Wraps Supabase Storage uploads and signed-URL retrieval. All buckets
/// (`profile-photos`, `audio-intros`, `nic-documents`) are private — every
/// display read goes through a short-lived signed URL, never a public path.
class StorageRepository {
  StorageRepository(this._client);

  final SupabaseClient _client;

  Future<String> uploadProfilePhoto(String userId, File file, {String ext = 'jpg'}) {
    return _upload(SupabaseConfig.profilePhotosBucket, '$userId/profile.$ext', file);
  }

  Future<String> uploadAudioIntro(String userId, File file, {String ext = 'm4a'}) {
    return _upload(SupabaseConfig.audioIntrosBucket, '$userId/intro.$ext', file);
  }

  Future<String> uploadNicFront(String userId, File file, {String ext = 'jpg'}) {
    return _upload(SupabaseConfig.nicDocumentsBucket, '$userId/nic_front.$ext', file);
  }

  Future<String> uploadNicBack(String userId, File file, {String ext = 'jpg'}) {
    return _upload(SupabaseConfig.nicDocumentsBucket, '$userId/nic_back.$ext', file);
  }

  Future<String> uploadSelfie(String userId, File file, {String ext = 'jpg'}) {
    return _upload(SupabaseConfig.nicDocumentsBucket, '$userId/selfie.$ext', file);
  }

  Future<String> _upload(String bucket, String path, File file) async {
    await _client.storage.from(bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  /// Returns a signed URL valid for [expiresInSeconds] (default 1 hour).
  Future<String> createSignedUrl(String bucket, String path, {int expiresInSeconds = 3600}) {
    return _client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  }

  Future<String> signedProfilePhotoUrl(String path, {int expiresInSeconds = 3600}) {
    return createSignedUrl(SupabaseConfig.profilePhotosBucket, path,
        expiresInSeconds: expiresInSeconds);
  }

  Future<String> signedAudioIntroUrl(String path, {int expiresInSeconds = 3600}) {
    return createSignedUrl(SupabaseConfig.audioIntrosBucket, path,
        expiresInSeconds: expiresInSeconds);
  }
}
