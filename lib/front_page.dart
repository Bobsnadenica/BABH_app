import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
// Amplify usage is through service helpers; explicit imports were removed to
// avoid unused import warnings in this file.
import 'amplify_storage.dart';
import 'auth_utils.dart';

// Shared logout action used in multiple AppBars to avoid duplicated code.
Widget logoutButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.logout),
    tooltip: 'Изход',
    onPressed: () async {
      await AuthUtils.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    },
  );
}

const List<String> folders = [
  'Входящ Контрол',
  'Изходящ контрол',
  'Темп. Хладилник',
  'Хигиена Обект',
  'Лична хигиена',
  'Обуч. Персонал',
  'ДДД',
];

class FrontPage extends StatefulWidget {
  const FrontPage({super.key});

  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State<FrontPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final groups = await AuthUtils.getUserGroups();
        if (groups.contains('admins') && mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminUsersPage()));
        }
      } catch (_) {}
    });
  }

  // folders moved to top-level `folders`

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневници'),
        actions: [logoutButton(context)],
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

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<String>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = AmplifyStorageService.listAllUserPrefixes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Потребителски пространства'),
        actions: [logoutButton(context)],
      ),
      body: FutureBuilder<List<String>>(
        future: _usersFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final users = snap.data ?? [];
          if (users.isEmpty) return const Center(child: Text('Няма намерени потребителски пространства'));
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                title: Text(u),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminUserFoldersPage(username: u)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class FolderPage extends StatefulWidget {
  final String folderName;
  final int assetIndex;
  final String? username; // if set, browse another user's space (admin)
  const FolderPage({super.key, required this.folderName, required this.assetIndex, this.username});

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
    // If an admin is browsing another user's space, use that username
    // for the local cache path so files for different remote users are
    // kept separate.
    final user = await Amplify.Auth.getCurrentUser();
    final owner = (widget.username != null && widget.username!.isNotEmpty) ? widget.username! : user.username;
    final dir = Directory('${base.path}/$owner/${widget.folderName}');
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
  final s3Items = await AmplifyStorageService.listFolder(widget.folderName, username: widget.username);
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

class AdminUserFoldersPage extends StatefulWidget {
  final String username;
  const AdminUserFoldersPage({super.key, required this.username});

  @override
  State<AdminUserFoldersPage> createState() => _AdminUserFoldersPageState();
}

class _AdminUserFoldersPageState extends State<AdminUserFoldersPage> {
  late Future<List<String>> _foldersFuture;

  @override
  void initState() {
    super.initState();
    _foldersFuture = AmplifyStorageService.listUserFolders(widget.username);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Дневници на: ${widget.username}'),
        actions: [logoutButton(context),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _foldersFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final userFolders = snap.data ?? [];
          if (userFolders.isEmpty) return const Center(child: Text('Няма намерени дневници за този потребител'));
          return ListView.builder(
            itemCount: userFolders.length,
            itemBuilder: (context, i) {
              final f = userFolders[i];
              return ListTile(
                title: Text(f),
                onTap: () {
                  // Use the canonical `folders` list to find a matching asset index.
                  final idx = folders.indexOf(f);
                  final assetIndex = (idx >= 0) ? (idx + 1) : 1;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderPage(folderName: f, assetIndex: assetIndex, username: widget.username),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}