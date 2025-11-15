import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:math' as math;
import 'app_config_service.dart';

/// Service for compressing image files while maintaining acceptable quality.
/// Balances file size reduction with visual quality preservation.
/// Uses configuration from S3 app_properties.json.
class ImageCompressionService {
  static const String _logPrefix = '🖼️';

  /// Compresses an image file in-place.
  /// Reduces dimensions if larger than max and applies JPEG compression.
  /// Returns the compression ratio (original / compressed).
  static Future<double> compressImage(File imageFile) async {
    try {
      final config = await AppConfigService.getConfig();
      final compressionMap = config['compression'] as Map<String, dynamic>? ?? {};
      final quality = compressionMap['quality'] as int? ?? 85;
      final maxWidth = compressionMap['maxWidth'] as int? ?? 1920;
      final maxHeight = compressionMap['maxHeight'] as int? ?? 1920;

      final originalSize = await imageFile.length();
      safePrint('$_logPrefix Compressing: ${imageFile.path} (${_formatBytes(originalSize)})');

      // Read the image
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        safePrint('$_logPrefix ⚠️ Could not decode image, skipping compression');
        return 1.0;
      }

      // Resize if larger than max dimensions
      if (image.width > maxWidth || image.height > maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height
              ? maxWidth
              : null,
          height: image.height > image.width
              ? maxHeight
              : null,
          interpolation: img.Interpolation.linear,
        );
        safePrint('$_logPrefix Resized to ${image.width}x${image.height}');
      }

      // Encode as JPEG with specified quality
      final compressedBytes = img.encodeJpg(image, quality: quality);
      
      // Write back to file
      await imageFile.writeAsBytes(compressedBytes);
      
      final compressedSize = await imageFile.length();
      final ratio = originalSize / compressedSize;
      
      safePrint('$_logPrefix ✅ Compressed: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} (${ratio.toStringAsFixed(2)}x smaller)');
      
      return ratio;
    } catch (e, st) {
      safePrint('$_logPrefix ❌ Compression failed: $e');
      safePrint(st.toString());
      rethrow;
    }
  }

  /// Compresses an image and converts it to JPEG.
  /// Writes a new file next to the original with the same basename and `.jpg` extension.
  /// Returns the resulting JPEG file.
  static Future<File> compressToJpeg(File imageFile) async {
    try {
      final config = await AppConfigService.getConfig();
      final compressionMap = config['compression'] as Map<String, dynamic>? ?? {};
      final quality = compressionMap['quality'] as int? ?? 85;
      final maxWidth = compressionMap['maxWidth'] as int? ?? 1920;
      final maxHeight = compressionMap['maxHeight'] as int? ?? 1920;

      final originalSize = await imageFile.length();
      safePrint('$_logPrefix Compressing to JPEG: ${imageFile.path} (${_formatBytes(originalSize)})');

      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        safePrint('$_logPrefix ⚠️ Could not decode image, returning original');
        return imageFile;
      }

      // Resize if larger than max dimensions while keeping aspect ratio
      if (image.width > maxWidth || image.height > maxHeight) {
        final scale = math.min(maxWidth / image.width, maxHeight / image.height);
        final newW = (image.width * scale).round();
        final newH = (image.height * scale).round();
        image = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);
        safePrint('$_logPrefix Resized to ${image.width}x${image.height}');
      }

      final compressedBytes = img.encodeJpg(image, quality: quality);

      final outPath = _replaceExtensionWith(imageFile.path, '.jpg');
      final outFile = File(outPath);
      await outFile.writeAsBytes(compressedBytes);

      final compressedSize = await outFile.length();
      final ratio = originalSize / compressedSize;
      safePrint('$_logPrefix ✅ JPEG: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} (${ratio.toStringAsFixed(2)}x smaller)');

      // Remove original to save space (if different)
      if (outFile.path != imageFile.path) {
        try {
          await imageFile.delete();
        } catch (_) {}
      }

      return outFile;
    } catch (e, st) {
      safePrint('$_logPrefix ❌ JPEG compression failed: $e');
      safePrint(st.toString());
      rethrow;
    }
  }

  /// Creates a thumbnail (JPEG) next to the original with suffix `_thumb.jpg`.
  /// Uses thumbnail dimensions and quality from app config.
  static Future<File?> createThumbnail(File imageFile) async {
    try {
      final config = await AppConfigService.getConfig();
      final compressionMap = config['compression'] as Map<String, dynamic>? ?? {};
      final thumbnailQuality = compressionMap['thumbnailQuality'] as int? ?? 70;
      final thumbnailWidth = compressionMap['thumbnailWidth'] as int? ?? 256;
      final thumbnailHeight = compressionMap['thumbnailHeight'] as int? ?? 256;

      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      final scale = math.min(thumbnailWidth / image.width, thumbnailHeight / image.height);
      final newW = (image.width * scale).round();
      final newH = (image.height * scale).round();

      final thumb = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);
      final thumbBytes = img.encodeJpg(thumb, quality: thumbnailQuality);

      final base = imageFile.path;
      final idx = base.lastIndexOf('.');
      final finalThumbPath = idx > 0 ? '${base.substring(0, idx)}_thumb.jpg' : '${base}_thumb.jpg';

      final thumbFile = File(finalThumbPath);
      await thumbFile.writeAsBytes(thumbBytes);
      safePrint('$_logPrefix ✅ Thumbnail created: ${_formatBytes(await thumbFile.length())}');
      return thumbFile;
    } catch (e, st) {
      safePrint('$_logPrefix ❌ Thumbnail creation failed: $e');
      safePrint(st.toString());
      return null;
    }
  }

  static String _replaceExtensionWith(String path, String ext) {
    final idx = path.lastIndexOf('.');
    if (idx > 0) return path.substring(0, idx) + ext;
    return path + ext;
  }

  /// Formats bytes as human-readable string (B, KB, MB, GB).
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

