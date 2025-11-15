import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:math' as math;

/// Service for compressing image files while maintaining acceptable quality.
/// Balances file size reduction with visual quality preservation.
class ImageCompressionService {
  static const String _logPrefix = '🖼️';
  
  // Compression settings for good balance between quality and size
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _jpegQuality = 85; // 0-100, higher = better quality but larger file
  static const int _thumbMaxDimension = 400;

  /// Compresses an image file in-place.
  /// Reduces dimensions if larger than max and applies JPEG compression.
  /// Returns the compression ratio (original / compressed).
  static Future<double> compressImage(File imageFile) async {
    try {
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
      if (image.width > _maxWidth || image.height > _maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height
              ? _maxWidth
              : null,
          height: image.height > image.width
              ? _maxHeight
              : null,
          interpolation: img.Interpolation.linear,
        );
        safePrint('$_logPrefix Resized to ${image.width}x${image.height}');
      }

      // Encode as JPEG with specified quality
      final compressedBytes = img.encodeJpg(image, quality: _jpegQuality);
      
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

  /// Compresses an image and converts it to WebP.
  /// Writes a new file next to the original with the same basename and `.webp` extension.
  /// Returns the resulting WebP file.
  static Future<File> compressToJpeg(File imageFile) async {
    try {
      final originalSize = await imageFile.length();
      safePrint('$_logPrefix Compressing to JPEG: ${imageFile.path} (${_formatBytes(originalSize)})');

      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        safePrint('$_logPrefix ⚠️ Could not decode image, returning original');
        return imageFile;
      }

      // Resize if larger than max dimensions while keeping aspect ratio
      if (image.width > _maxWidth || image.height > _maxHeight) {
        final scale = math.min(_maxWidth / image.width, _maxHeight / image.height);
        final newW = (image.width * scale).round();
        final newH = (image.height * scale).round();
        image = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);
        safePrint('$_logPrefix Resized to ${image.width}x${image.height}');
      }

      final compressedBytes = img.encodeJpg(image, quality: _jpegQuality);

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

  /// Creates a thumbnail (WebP) next to the original with suffix `_thumb.webp`.
  static Future<File?> createThumbnail(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      final scale = math.min(_thumbMaxDimension / image.width, _thumbMaxDimension / image.height);
      final newW = (image.width * scale).round();
      final newH = (image.height * scale).round();

      final thumb = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);
      final thumbBytes = img.encodeJpg(thumb, quality: (_jpegQuality - 20).clamp(30, 80));

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
