import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class OCRService {
  static Future<String> _resolveTessDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final tessDir = Directory('${docs.path}/tessdata');
    if (!await tessDir.exists()) {
      await tessDir.create(recursive: true);
    }
    return tessDir.path;
  }

  static Future<void> _prepareTessData() async {
    final tessPath = await _resolveTessDir();
    final bulFile = File('$tessPath/bul.traineddata');
    if (!await bulFile.exists()) {
      final data = await rootBundle.load('assets/tessdata/bul.traineddata');
      await bulFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
  }

  static Future<String> extractText(String imagePath) async {
    try {
      await _prepareTessData();
      final tessDir = await _resolveTessDir();

      final args = {
        'psm': '6',
        'oem': '1',
        'tessdata': tessDir,
        'user_words': <String>[],
        'user_patterns': <String>[],
        'configs': <String>[],
        'variables': <String, String>{'debug_file': '/dev/null'},
      };

      debugPrint('🔧 OCR args: $args');
      debugPrint('📁 Tessdata exists: ${await Directory(tessDir).exists()}');
      debugPrint('📄 bul.traineddata exists: ${await File("$tessDir/bul.traineddata").exists()}');

      final text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'bulgarian',
        args: args,
      );

      return text.trim();
    } catch (e, st) {
      debugPrint('❌ OCR failed: $e\n$st');
      return '';
    }
  }
}