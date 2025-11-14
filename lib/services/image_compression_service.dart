import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:amplify_flutter/amplify_flutter.dart';

/// Service for compressing image files while maintaining acceptable quality.
/// Balances file size reduction with visual quality preservation.
class ImageCompressionService {
  static const String _logPrefix = '🖼️';
  
  // Compression settings for good balance between quality and size
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _jpegQuality = 85; // 0-100, higher = better quality but larger file

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

  /// Formats bytes as human-readable string (B, KB, MB, GB).
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
