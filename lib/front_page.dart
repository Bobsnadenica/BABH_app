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
import 'amplify_storage.dart';

class FrontPage extends StatelessWidget {
  const FrontPage({super.key});

  static const List<String> folders = [
    'Входящ Контрол',
    'Изходящ контрол',
    'Темп. Хладилник',
    'Хигиена Обект',
    'Лична хигиена',
    'Обуч. Персонал',
    'ggg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневници'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5FB), Color(0xFFE3F2FD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Изберете дневник',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Снимайте и съхранявайте документи по категории. Всичко е подредено и синхронизирано сигурно.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: folders.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final name = folders[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderPage(
                                folderName: name,
                                assetIndex: index + 1,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black12,
                          clipBehavior: Clip.antiAlias,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/${index + 1}.png',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.folder_special_rounded,
                                size: 64,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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

  Future<void> _deletePhoto(File file) async {
    try {
      await AmplifyStorageService.deleteFile(file, widget.folderName);
      setState(() => _imagesFuture = _loadImages());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Изображението е изтрито.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка при изтриване: $e')),
      );
    }
  }

  Future<File?> _normalizeScannedResult(dynamic scanned, String savePath) async {
    try {
      if (scanned == null) return null;
      if (scanned is File) {
        return await File(scanned.path).copy(savePath);
      }
      final dynamic path = (scanned as dynamic).path;
      if (path is String && path.isNotEmpty) {
        return await File(path).copy(savePath);
      }
      if (scanned is List && scanned.isNotEmpty) {
        final first = scanned.first;
        final dynamic p = (first as dynamic).path;
        if (p is String && p.isNotEmpty) {
          return await File(p).copy(savePath);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Directory> _ensureFolder() async {
    final base = await getApplicationDocumentsDirectory();
    final user = await Amplify.Auth.getCurrentUser();
    final dir = Directory('${base.path}/${user.username}/${widget.folderName}');
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
      // Prevent duplicate uploads and saves for the same day within a folder
      final todayPrefix = DateTime.now().toIso8601String().split('T').first;
      final existing = folder.listSync().where((f) => f.path.contains(todayPrefix));
      final count = existing.length;
      final savePath = '${folder.path}/${todayPrefix}_${count + 1}.jpg';

      await File(photo.path).copy(savePath);

      try {
        await AmplifyStorageService.uploadFile(File(savePath), widget.folderName);
      } catch (e) {
        // removed debugPrint
      }

      if (!mounted) return;
      setState(() => _imagesFuture = _loadImages());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документът е заснет и запазен успешно.')),
      );
    } catch (e) {
      if (!mounted) return;
      // removed debugPrint
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
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncFromS3,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5FB), Color(0xFFE3F2FD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<File>>(
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
              return const Center(
                child: Text(
                  'Няма изображения.\nНатиснете бутона за сканиране, за да добавите първия документ.',
                  textAlign: TextAlign.center,
                ),
              );
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
                  final parsed = DateTime.tryParse(nameWithoutExt) ?? DateTime.now();
                  dateLabel =
                      '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
                } catch (_) {
                  dateLabel = '';
                }
                return GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black.withOpacity(0.8),
                      insetPadding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Stack(
                        children: [
                          InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(file, fit: BoxFit.contain),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
                              onPressed: () async {
                                Navigator.pop(context);
                                await _deletePhoto(file);
                              },
                            ),
                          ),
                          if (dateLabel.isNotEmpty)
                            Positioned(
                              bottom: 12,
                              left: 16,
                              child: Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(file, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (dateLabel.isNotEmpty)
                        Text(
                          dateLabel,
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
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

  Future<void> _syncFromS3() async {
    try {
      final localDir = await _ensureFolder();
      final s3Items = await AmplifyStorageService.listFolder(widget.folderName);
      for (final item in s3Items) {
        final fileName = item.key.split('/').last;
        final localFile = File('${localDir.path}/$fileName');
        if (!await localFile.exists()) {
          await AmplifyStorageService.downloadFile(item.key, localFile);
        }
      }

      setState(() => _imagesFuture = _loadImages());
      if (!mounted) return;
      // Hide any previous snackbar before showing a new one
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Синхронизацията е завършена.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка при синхронизация: $e')),
      );
    }
  }
}