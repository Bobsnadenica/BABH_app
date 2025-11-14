import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../amplify_storage.dart';
import 'image_compression_service.dart';

/// Service for managing local and cloud image operations.
/// Handles all business logic for image capture, storage, and synchronization.
class ImageService {
  static const String _logPrefix = '📸';

  /// Ensures the folder exists for a given folder name and current user.
  /// Creates the folder structure if it doesn't exist.
  Future<Directory> ensureFolder(String folderName) async {
    final base = await getApplicationDocumentsDirectory();
    final user = await Amplify.Auth.getCurrentUser();
    final dir = Directory('${base.path}/${user.username}/$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all image files from the local folder.
  /// Returns a sorted list (newest first) of .jpg and .png files.
  Future<List<File>> loadImages(String folderName) async {
    final dir = await ensureFolder(folderName);
    final List<File> files = [];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final p = entity.path.toLowerCase();
        if (p.endsWith('.jpg') || p.endsWith('.png')) {
          files.add(entity);
        }
      }
    }
    // Sort by newest first
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Captures a photo from the camera and saves it locally.
  /// Returns the local file path if successful.
  /// Throws an exception if capture fails or is cancelled.
  Future<String> capturePhotoLocally(String folderName) async {
    final folder = await ensureFolder(folderName);
    final todayPrefix = DateTime.now().toIso8601String().split('T').first;
    final existing = folder.listSync().where((f) => f.path.contains(todayPrefix));
    final count = existing.length;
    return '${folder.path}/${todayPrefix}_${count + 1}.jpg';
  }

  /// Uploads a local photo file to S3 storage.
  /// Compresses the image before upload to reduce bandwidth and storage costs.
  /// Returns true if successful, throws exception on failure.
  Future<void> uploadPhoto(File photoFile, String folderName) async {
    final localPath = photoFile.path;
    safePrint('$_logPrefix → Starting upload from service: local=$localPath folder=$folderName');
    try {
      // Compress image before uploading
      await ImageCompressionService.compressImage(photoFile);
      
      await AmplifyStorageService.uploadFile(photoFile, folderName);
      safePrint('$_logPrefix ✅ Upload successful: $localPath');
    } catch (e, st) {
      safePrint('$_logPrefix ❌ Upload failed: $e');
      safePrint(st.toString());
      rethrow;
    }
  }

  /// Deletes a local and cloud photo file.
  /// Syncs the deletion to S3 storage.
  Future<void> deletePhoto(File file, String folderName) async {
    await AmplifyStorageService.deleteFile(file, folderName);
    safePrint('$_logPrefix 🗑️ Photo deleted: ${file.path}');
  }

  /// Synchronizes photos from S3 to local storage.
  /// Downloads any missing S3 files to the local folder.
  Future<int> syncPhotosFromS3(String folderName) async {
    int downloadCount = 0;
    final localDir = await ensureFolder(folderName);
    
    try {
      final s3Items = await AmplifyStorageService.listFolder(folderName);
      safePrint('$_logPrefix Found ${s3Items.length} items in S3');
      
      for (final item in s3Items) {
        final fileName = item.key.split('/').last;
        final localFile = File('${localDir.path}/$fileName');
        if (!await localFile.exists()) {
          await AmplifyStorageService.downloadFile(item.key, localFile);
          downloadCount++;
          safePrint('$_logPrefix ⬇️ Downloaded: $fileName');
        }
      }
      safePrint('$_logPrefix ✅ Sync complete: $downloadCount files downloaded');
    } catch (e, st) {
      safePrint('$_logPrefix ❌ Sync failed: $e');
      safePrint(st.toString());
      rethrow;
    }
    
    return downloadCount;
  }

  /// Extracts date from filename (ISO8601 format: YYYY-MM-DD).
  /// Returns formatted date string or empty string if parsing fails.
  String extractDateLabel(String fileName) {
    try {
      final nameWithoutExt = fileName.split('.').first;
      final parsed = DateTime.tryParse(nameWithoutExt) ?? DateTime.now();
      return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
    } catch (_) {
      return '';
    }
  }
}
