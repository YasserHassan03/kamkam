import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

/// Service for handling file uploads to Supabase Storage
class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  /// Upload an organisation logo to Supabase Storage
  /// 
  /// Returns the public URL of the uploaded image.
  /// The image is stored at: logos/organisations/{orgId}/logo.{extension}
  Future<String> uploadOrganisationLogo({
    required String orgId,
    required File imageFile,
  }) async {
    try {
      // Get file extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'logo.$extension';
      final storagePath = 'organisations/$orgId/$fileName';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage (upsert to replace existing)
      await _client.storage
          .from(AppConstants.logosBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(AppConstants.logosBucket)
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading organisation logo: $e');
      rethrow;
    }
  }

  /// Delete an organisation logo from Supabase Storage
  Future<void> deleteOrganisationLogo(String orgId) async {
    try {
      // List all files in the organisation folder
      final files = await _client.storage
          .from(AppConstants.logosBucket)
          .list(path: 'organisations/$orgId');

      if (files.isNotEmpty) {
        final paths = files
            .map((f) => 'organisations/$orgId/${f.name}')
            .toList();
        await _client.storage
            .from(AppConstants.logosBucket)
            .remove(paths);
      }
    } catch (e) {
      debugPrint('Error deleting organisation logo: $e');
      // Don't rethrow - deletion failure shouldn't block other operations
    }
  }

  /// Get the content type for a file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Upload a sponsor logo for a tournament to Supabase Storage
  /// 
  /// Returns the public URL of the uploaded image.
  /// The image is stored at: logos/sponsors/{tournamentId}/sponsor.{extension}
  Future<String> uploadSponsorLogo({
    required String tournamentId,
    required File imageFile,
  }) async {
    try {
      // Get file extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'sponsor.$extension';
      final storagePath = 'sponsors/$tournamentId/$fileName';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage (upsert to replace existing)
      await _client.storage
          .from(AppConstants.logosBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(AppConstants.logosBucket)
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading sponsor logo: $e');
      rethrow;
    }
  }

  /// Upload a sponsor logo from bytes (better iOS compatibility)
  Future<String> uploadSponsorLogoBytes({
    required String tournamentId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final extension = fileExtension.toLowerCase().replaceAll('.', '');
      final fileName = 'sponsor.$extension';
      final storagePath = 'sponsors/$tournamentId/$fileName';

      // Upload to Supabase Storage (upsert to replace existing)
      await _client.storage
          .from(AppConstants.logosBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(AppConstants.logosBucket)
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading sponsor logo bytes: $e');
      rethrow;
    }
  }

  /// Delete a sponsor logo from Supabase Storage
  Future<void> deleteSponsorLogo(String tournamentId) async {
    try {
      // List all files in the sponsor folder
      final files = await _client.storage
          .from(AppConstants.logosBucket)
          .list(path: 'sponsors/$tournamentId');

      if (files.isNotEmpty) {
        final paths = files
            .map((f) => 'sponsors/$tournamentId/${f.name}')
            .toList();
        await _client.storage
            .from(AppConstants.logosBucket)
            .remove(paths);
      }
    } catch (e) {
      debugPrint('Error deleting sponsor logo: $e');
      // Don't rethrow - deletion failure shouldn't block other operations
    }
  }
}
