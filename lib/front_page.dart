import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';

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

  Future<void> _scanAndSave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Камерата не се поддържа в уеб. Използвайте устройство.')),
        );
        return;
      }

      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Снимането е отменено.')),
        );
        return;
      }

      final folder = await _ensureFolder();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final savePath = '${folder.path}/$timestamp.jpg';

      await File(photo.path).copy(savePath);

      try {
        final user = await Amplify.Auth.getCurrentUser();
        final key = '${user.userId}/${widget.folderName}/$timestamp.jpg';
        await Amplify.Storage.uploadFile(
          localFile: AWSFile.fromPath(savePath),
          key: key,
        );
        debugPrint('✅ Uploaded to S3: $key');
      } catch (e) {
        debugPrint('⚠️ Upload to S3 failed: $e');
      }

      if (!mounted) return;
      setState(() => _imagesFuture = _loadImages());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документът е заснет и запазен успешно.')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ scanAndSave error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка при заснемане: $e')),
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
            itemBuilder: (_, i) {
              final file = images[i];
              final fileName = file.path.split('/').last;
              String dateLabel = '';
              try {
                final nameWithoutExt = fileName.split('.').first;
                final parsed = DateTime.tryParse(nameWithoutExt.replaceAll('-', ':')) ?? DateTime.now();
                dateLabel = '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
              } catch (_) {
                dateLabel = '';
              }
              return GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(child: Image.file(file, fit: BoxFit.contain)),
                ),
                child: Column(
                  children: [
                    Expanded(child: Image.file(file, fit: BoxFit.cover)),
                    const SizedBox(height: 4),
                    Text(dateLabel, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            },
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