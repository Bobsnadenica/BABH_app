import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:document_scanner_flutter/document_scanner_flutter.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

class FrontPage extends StatelessWidget {
  const FrontPage({super.key});

  static const List<String> folders = [
    'Входящ Контрол',
    'Изходящ контрол',
    'Дневник на хигиенистка/персонал',
    'Дневник за хигиенистка на обекта',
    'Температура на хладилниците',
    'Температура на Бенмарита',
    'ДДД Дневник',
    'Дневник за инструкции по системите',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Дневници')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          itemCount: folders.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3 / 2,
          ),
          itemBuilder: (context, index) {
            final name = folders[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FolderPage(folderName: name, assetIndex: index + 1),
                ),
              ),
              child: Card(
                elevation: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          'assets/${index + 1}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.folder, size: 48),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                      child: Text(name, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FolderPage extends StatefulWidget {
  final String folderName;
  final int assetIndex;
  const FolderPage({super.key, required this.folderName, required this.assetIndex});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  bool _busy = false;
  late Future<List<File>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  /// Normalize scanned result from document_scanner_flutter and save to savePath.
  Future<File?> _normalizeScannedResult(dynamic scanned, String savePath) async {
    try {
      if (scanned == null) return null;
      // document_scanner_flutter may return a File or an XFile (or platform type with path)
      if (scanned is File) {
        return await File(scanned.path).copy(savePath);
      }
      // Common pattern: scanned has a 'path' getter
      final dynamic path = (scanned as dynamic).path;
      if (path is String && path.isNotEmpty) {
        return await File(path).copy(savePath);
      }
      // Fallback: list of pages -> take first
      if (scanned is List && scanned.isNotEmpty) {
        final first = scanned.first;
        final dynamic p = (first as dynamic).path;
        if (p is String && p.isNotEmpty) {
          return await File(p).copy(savePath);
        }
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ normalizeScannedResult error: $e');
      return null;
    }
  }

  Future<Directory> _ensureFolder() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/${widget.folderName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<File>> _loadImages() async {
    final dir = await _ensureFolder();
    final List<File> files = [];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final p = entity.path.toLowerCase();
        if (p.endsWith('.jpg') || p.endsWith('.png')) {
          files.add(entity);
        }
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> _showProgress(String message) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _prepareTessData() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final tessdataDir = Directory('${baseDir.path}/tessdata');
    if (!await tessdataDir.exists()) {
      await tessdataDir.create(recursive: true);
    }
    final trainedDataFile = File('${tessdataDir.path}/bul.traineddata');
    if (!await trainedDataFile.exists()) {
      try {
        final dataAsset = await rootBundle.load('assets/tessdata/bul.traineddata');
        await trainedDataFile.writeAsBytes(dataAsset.buffer.asUint8List(), flush: true);
        debugPrint('📦 bul.traineddata exists after copy: ${await trainedDataFile.exists()}');
      } catch (e) {
        debugPrint('⚠️ Could not copy tessdata file: $e');
      }
    }
    return baseDir.path;
  }

  Future<String> _safeExtractText(String imagePath, String language, Map<String, dynamic> args) async {
    // Defensive deep copy and normalization
    final normalized = <String, dynamic>{};
    args.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        normalized[key] = value.whereType<String>().toList();
      } else if (value is Map) {
        normalized[key] = Map<String, dynamic>.from(value);
      } else {
        normalized[key] = value;
      }
    });

    // Guarantee structure expected by plugin
    normalized.putIfAbsent("user_words", () => <String>[]);
    normalized.putIfAbsent("user_patterns", () => <String>[]);
    normalized.putIfAbsent("configs", () => <String>[]);
    normalized.putIfAbsent("variables", () => <String>[]);

    debugPrint('🧩 Normalized OCR args: $normalized');

    return await FlutterTesseractOcr.extractText(
      imagePath,
      language: language,
      args: normalized,
    );
  }

  Future<void> _scanAndSave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сканирането не се поддържа в уеб. Използвайте устройство.')),
        );
        return;
      }

      // Ensure folder exists and compute save path
      final folder = await _ensureFolder();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final savePath = '${folder.path}/$timestamp.jpg';

      // Try scanner
      dynamic scanned = await DocumentScannerFlutter.launch(context);

      if (scanned == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сканирането е отменено.')),
        );
        return;
      }

      final saved = await _normalizeScannedResult(scanned, savePath);
      if (saved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неуспешно запазване на сканираното изображение.')),
        );
        return;
      }

      // Show progress while extracting text
      await _showProgress('Разпознаване на текст…');

      final tessdataBasePath = await _prepareTessData();

      debugPrint('📁 Using tessdata from: $tessdataBasePath/tessdata');
      debugPrint('📄 File exists: ${await File("$tessdataBasePath/tessdata/bul.traineddata").exists()}');

      // Optional: sanity check for tessdata presence (best-effort)
      // We avoid throwing here; just inform the user if model is missing.
      String extractedText = '';
      try {
        final Map<String, dynamic> ocrArgs = {
          "psm": "6",
          "oem": "1",
          "tessdata": "$tessdataBasePath/tessdata",
          "preserve_interword_spaces": "1",
          "user_words": [" "], // Safe placeholder to avoid null iterable
          "user_patterns": [" "],
          "configs": [
            "--tessdata-dir",
            "$tessdataBasePath/tessdata",
            "--tessedit_char_blacklist",
            "|"
          ],
          "variables": {"debug_file": "/dev/null"}, // silent mode
        };

        // Clean nulls and ensure all fields are iterable-safe
        ocrArgs.removeWhere((_, v) => v == null);

        debugPrint('🔧 OCR args: $ocrArgs');

        try {
          extractedText = await _safeExtractText(saved.path, 'bul', ocrArgs);
        } catch (e, st) {
          debugPrint('⚠️ Tesseract error: $e\n$st');
          extractedText = '';
        }
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop(); // close progress
      }

      if (!mounted) return;
      setState(() => _imagesFuture = _loadImages());

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Извлечен текст'),
          content: SingleChildScrollView(
            child: Text(
              (extractedText.isEmpty)
                  ? 'Няма открит текст. Уверете се, че файлът assets/tessdata/bul.traineddata е добавен в проекта и изображението е ясно.'
                  : extractedText,
            ),
          ),
          actions: [
            if (extractedText.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: extractedText));
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Текстът е копиран')),
                    );
                  }
                },
                child: const Text('Копирай'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Затвори'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ scanAndSave error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка при сканиране: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      body: FutureBuilder<List<File>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Грешка при зареждане на изображенията'));
          }
          final images = snapshot.data ?? [];
          if (images.isEmpty) {
            return const Center(child: Text('Няма изображения. Натиснете бутона за сканиране, за да добавите.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: images.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(child: Image.file(images[i], fit: BoxFit.contain)),
              ),
              child: Image.file(images[i], fit: BoxFit.cover),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _scanAndSave,
        tooltip: 'Сканирай документ (камера)',
        child: _busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.document_scanner),
      ),
    );
  }
}