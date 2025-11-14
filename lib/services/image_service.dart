import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../amplify_storage.dart';
import 'image_compression_service.dart';

/// Service for managing local and cloud image operations.
/// Handles all business logic for image capture, storage, and synchronization.
class ImageService {
  static const String _logPrefix = '📸';

  /// Ensures the folder exists for a given folder name and current user (or specified username for admin).
  /// Creates the folder structure if it doesn't exist.
  Future<Directory> ensureFolder(String folderName, {String? username}) async {
    final base = await getApplicationDocumentsDirectory();
    final user = await Amplify.Auth.getCurrentUser();
    final owner = username ?? user.username;
    final dir = Directory('${base.path}/$owner/$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all image files from the local folder, or from S3 if browsing another user (admin).
  /// Returns a sorted list (newest first) of .jpg and .png files.
  /// If [username] is provided and differs from current user, loads from S3 directly (admin use).
  Future<List<File>> loadImages(String folderName, {String? username}) async {
    final currentUser = await Amplify.Auth.getCurrentUser();
    final isAdmin = username != null && username != currentUser.username;

    if (isAdmin) {
      // Admin browsing another user: load from S3, create local temp files for display
      final s3Items = await AmplifyStorageService.listFolder(folderName, username: username);
      final localDir = await ensureFolder(folderName, username: username);
      final Map<String, File> map = {};

      for (final item in s3Items) {
        final fileName = item.key.split('/').last;
        // Skip thumbnails in the main list (grid will prefer thumbs if available)
        if (fileName.contains('_thumb')) continue;
        if (!(fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.png'))) continue;

        // Create reference to local file (may not exist yet; will be downloaded on demand)
        final localFile = File('${localDir.path}/$fileName');
        map[fileName] = localFile;
      }

      final files = map.values.toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } else {
      // Regular user: load from local cache
      final dir = await ensureFolder(folderName, username: username);
      final Map<String, File> map = {};

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final p = entity.path;
          final lower = p.toLowerCase();
          if (!(lower.endsWith('.jpg') || lower.endsWith('.png'))) continue;

          final fileName = p.split('/').last;
          if (fileName.contains('_thumb')) {
            // Thumbnail only: store as placeholder if main not present
            final base = fileName.replaceFirst('_thumb', '');
            map.putIfAbsent(base, () => File(p));
          } else {
            // Main image: prefer main over thumbnail
            map[fileName] = File(p);
          }
        }
      }

      final files = map.values.toList();
      // Sort by filename descending (newest first assuming ISO date prefix)
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    }
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
      // Compress image (convert/optimize) and create thumbnail
      final compressed = await ImageCompressionService.compressToJpeg(photoFile);
      final thumb = await ImageCompressionService.createThumbnail(compressed);

      // Upload main file
      await AmplifyStorageService.uploadFile(compressed, folderName);
      safePrint('$_logPrefix ✅ Upload successful: ${compressed.path}');

      // Upload thumbnail if present
      if (thumb != null) {
        await AmplifyStorageService.uploadFile(thumb, folderName);
        safePrint('$_logPrefix ✅ Thumbnail uploaded: ${thumb.path}');
      }
    } catch (e, st) {
      safePrint('$_logPrefix ❌ Upload failed: $e');
      safePrint(st.toString());
      rethrow;
    }
  }

  /// Deletes a local and cloud photo file.
  /// Syncs the deletion to S3 storage.
  Future<void> deletePhoto(File file, String folderName, {String? username}) async {
    // Move files to an app-managed trash folder instead of permanently deleting locally.
    final fileName = file.path.split('/').last;
    final idx = fileName.lastIndexOf('.');
    final baseName = fileName.contains('_thumb') ? fileName.replaceFirst('_thumb', '') : fileName;
    final thumbName = idx > 0
        ? '${baseName.substring(0, baseName.lastIndexOf('.'))}_thumb${baseName.substring(baseName.lastIndexOf('.'))}'
        : '${baseName}_thumb';

    try {
      // Delete remote main file immediately (respect optional username for admin)
      await AmplifyStorageService.deleteRemoteFileByName(
        fileName.contains('_thumb') ? baseName : fileName,
        folderName,
        username: username,
      );
    } catch (e) {
      safePrint('$_logPrefix ⚠️ Remote main delete failed (may not exist): $e');
    }

    // Also attempt to delete remote thumbnail
    try {
      await AmplifyStorageService.deleteRemoteFileByName(thumbName, folderName, username: username);
    } catch (e) {
      safePrint('$_logPrefix ⚠️ Remote thumbnail delete failed (may not exist): $e');
    }

    // Move local main file and local thumbnail (if present) into trash
    try {
      final localDir = await ensureFolder(folderName, username: username);
      final trashDir = Directory('${localDir.path}/trash');
      if (!await trashDir.exists()) await trashDir.create(recursive: true);

      // Move main file (if exists and not already in trash)
      if (await file.exists()) {
        final newPath = '${trashDir.path}/$fileName';
        try {
          await file.rename(newPath);
          safePrint('$_logPrefix 📦 Moved to trash: $fileName');
        } catch (_) {
          // Fallback to copy+delete if rename fails
          await file.copy(newPath);
          await file.delete();
          safePrint('$_logPrefix 📦 Copied to trash then deleted original: $fileName');
        }
      }

      // Move thumbnail if exists
      final localThumb = File('${localDir.path}/$thumbName');
      if (await localThumb.exists()) {
        final newThumbPath = '${trashDir.path}/$thumbName';
        try {
          await localThumb.rename(newThumbPath);
          safePrint('$_logPrefix 📦 Thumbnail moved to trash: $thumbName');
        } catch (_) {
          await localThumb.copy(newThumbPath);
          await localThumb.delete();
          safePrint('$_logPrefix 📦 Thumbnail copied to trash then deleted original: $thumbName');
        }
      }
    } catch (e) {
      safePrint('$_logPrefix ⚠️ Failed to move files to trash: $e');
      // As a fallback, try to delete local file to avoid inconsistent state
      try { if (await file.exists()) await file.delete(); } catch (_) {}
    }
  }

  /// Synchronizes photos from S3 to local storage.
  /// Downloads any missing S3 files to the local folder.
  /// If [username] is provided, syncs from another user's space (admin use).
  Future<int> syncPhotosFromS3(String folderName, {String? username}) async {
    int downloadCount = 0;
    final localDir = await ensureFolder(folderName);
    
    try {
      final s3Items = await AmplifyStorageService.listFolder(folderName, username: username);
      safePrint('$_logPrefix Found ${s3Items.length} items in S3');
      // Build a set of base filenames that exist in S3 (strip `_thumb` suffix)
      final Set<String> s3BaseNames = {};
      for (final item in s3Items) {
        final fileName = item.key.split('/').last;
        final baseName = fileName.contains('_thumb') ? fileName.replaceFirst('_thumb', '') : fileName;
        s3BaseNames.add(baseName);

        // Only download thumbnail objects during sync to save bandwidth.
        if (!fileName.contains('_thumb')) continue;

        final localFile = File('${localDir.path}/$fileName');
        if (!await localFile.exists()) {
          await AmplifyStorageService.downloadFile(item.key, localFile);
          downloadCount++;
          safePrint('$_logPrefix ⬇️ Downloaded thumbnail: $fileName');
        }
      }

      // Prune local files that don't exist in S3 anymore.
      // For each local file, compute its baseName and delete if not present on S3.
      final List<FileSystemEntity> localEntities = await localDir.list(followLinks: false).toList();
      for (final entity in localEntities) {
        if (entity is! File) continue;
        final path = entity.path;
        final lower = path.toLowerCase();
        if (!(lower.endsWith('.jpg') || lower.endsWith('.png'))) continue;

        final fileName = path.split('/').last;
        final localBase = fileName.contains('_thumb') ? fileName.replaceFirst('_thumb', '') : fileName;
        if (!s3BaseNames.contains(localBase)) {
          try {
            await entity.delete();
            safePrint('$_logPrefix 🧹 Removed stale local file: $fileName');
          } catch (e) {
            safePrint('$_logPrefix ⚠️ Failed to delete local stale file $fileName: $e');
          }
        }
      }

      // Auto-purge trashed files older than retention (30 days by default)
      try {
        await _purgeTrash(folderName, days: 30);
      } catch (e) {
        safePrint('$_logPrefix ⚠️ Purge trash failed: $e');
      }

      safePrint('$_logPrefix ✅ Sync complete: $downloadCount files downloaded');
    } catch (e, st) {
      safePrint('$_logPrefix ❌ Sync failed: $e');
      safePrint(st.toString());
      rethrow;
    }
    
    return downloadCount;
  }

  /// Purges files from the app-managed trash that are older than [days].
  /// This only removes local files from the app's documents directory (safe across platforms).
  Future<void> _purgeTrash(String folderName, {int days = 30}) async {
    if (days <= 0) return;
    final localDir = await ensureFolder(folderName);
    final trashDir = Directory('${localDir.path}/trash');
    if (!await trashDir.exists()) return;

    final cutoff = DateTime.now().subtract(Duration(days: days));
    await for (final entity in trashDir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) {
          await entity.delete();
          safePrint('$_logPrefix 🧹 Purged trash file: ${entity.path.split('/').last}');
        }
      } catch (e) {
        safePrint('$_logPrefix ⚠️ Failed to purge file ${entity.path}: $e');
      }
    }
  }

  /// Extracts date from filename (YYYY-MM-DD or YYYY-MM-DD_xx patterns).
  /// Returns formatted date string or empty string if parsing fails.
  String extractDateLabel(String fileName) {
    try {
      // Remove thumbnail marker if present
      var name = fileName.replaceFirst('_thumb', '');

      // Remove extension
      final nameWithoutExt = name.split('.').first;

      // Extract only the date part (before the underscore, if any)
      final parts = nameWithoutExt.split('_');
      final datePart = parts.isNotEmpty ? parts.first : nameWithoutExt;

      final parsed = DateTime.tryParse(datePart);
      if (parsed == null) return '';

      return '${parsed.day.toString().padLeft(2, '0')}.'
          '${parsed.month.toString().padLeft(2, '0')}.'
          '${parsed.year}';
    } catch (_) {
      return '';
    }
  }
}
