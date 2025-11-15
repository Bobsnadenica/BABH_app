import 'dart:io';
import 'package:babh_dnevnicite/widgets/network_connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../amplify_storage.dart';
import '../services/image_service.dart';
import '../widgets/background_logo.dart';
import '../widgets/image_grid.dart';

/// Folder page for managing photos within a specific folder.
/// Handles camera capture, upload to S3, and sync from cloud.
/// If [username] is provided, admin can browse another user's space.
class FolderPage extends StatefulWidget {
  final String folderName;
  final int assetIndex;
  final String? username;

  const FolderPage({
    super.key,
    required this.folderName,
    required this.assetIndex,
    this.username,
  });

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  late final ImageService _imageService = ImageService();
  bool _busy = false;
  String _loadingMessage = '';
  late Future<List<File>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _imageService.loadImages(widget.folderName, username: widget.username);
  }

  /// Refreshes the image list by reloading from disk.
  void _refreshImageList() {
    final imagesFuture = _imageService.loadImages(widget.folderName, username: widget.username);
    setState(() {
      _imagesFuture = imagesFuture;
    });
  }

  /// Handles opening an image. If the full image is not present locally,
  /// downloads it from S3 (thumbnail-first strategy) and then shows it.
  Future<void> _handleOpenImage(File previewFile, String baseName) async {
    if (!await checkInternetAndShowDialog(context)) return; // must come first
    final localDir = await _imageService.ensureFolder(widget.folderName);
    final fullLocal = File('${localDir.path}/$baseName');

    if (!await fullLocal.exists()) {
      if (_busy) return;
      setState(() {
        _busy = true;
        _loadingMessage = 'Изтегляне на пълно изображение...';
      });

      try {
        final user = await Amplify.Auth.getCurrentUser();
        // Use admin-provided username if available, otherwise use current user
        final owner = (widget.username != null && widget.username!.isNotEmpty) ? widget.username! : user.username;
        final key = '$owner/${widget.folderName}/$baseName';
        await AmplifyStorageService.downloadFile(key, fullLocal);
        safePrint('📸 ⬇️ Downloaded full image: $baseName');
      } catch (e) {
        _showMessage('Грешка при сваляне на изображението: $e');
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    if (!mounted) return;
    _showFullImageDialog(fullLocal);
  }

  void _showFullImageDialog(File file) {
    final fileName = file.path.split('/').last;
    final dateLabel = _imageService.extractDateLabel(fileName);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            // Close button (top-right)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6), // semi-transparent dark background
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8), // extra padding inside circle
                  constraints: const BoxConstraints(), // remove default constraints for smaller circle
                ),
              ),
            ),

            // Delete button (bottom-right)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8), // semi-transparent light background
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    _handleDeletePhoto(file);
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
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
    );
  }

  /// Handles photo deletion with error handling and UI feedback.
  Future<void> _handleDeletePhoto(File file) async {
    if (!await checkInternetAndShowDialog(context)) return; // must come first
    try {
      await _imageService.deletePhoto(file, widget.folderName, username: widget.username);
      if (mounted) {
        _refreshImageList();
        _showMessage('🗑️ Изображението е изтрито.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Грешка при изтриване: $e');
      }
    }
  }

/// Captures a photo from camera, saves locally, and uploads to S3.
/// Supports multiple pages.
  /// Captures a photo from camera, saves locally, and uploads to S3.
/// Supports multiple pages and handles cancellations safely.
  Future<void> _handleCapturePhoto() async {
    if (!await checkInternetAndShowDialog(context)) return; // must come first
    if (_busy) return;

    setState(() {
      _busy = true;
      _loadingMessage = 'Снимане...';
    });

    try {
      if (kIsWeb) {
        _showMessage('Камерата не се поддържа в уеб. Използвайте устройство.');
        return;
      }

      // ---- ML KIT DOCUMENT SCANNER ----
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.base,
          isGalleryImport: false,
          pageLimit: 10, // allow multiple pages
        ),
      );

      DocumentScanningResult? scanningResult;

      try {
        scanningResult = await scanner.scanDocument();
      } catch (e) {
        // User closed scanner or an error occurred
        _showMessage('Сканирането е отменено.');
        return;
      }

      if (scanningResult.images.isEmpty) {
        _showMessage('Сканирането е отменено.');
        return;
      }

      if (mounted) setState(() => _loadingMessage = 'Запазване локално...');

      // ---- SAVE & UPLOAD EACH SCANNED PAGE ----
      for (var scannedImagePath in scanningResult.images) {
        final savePath = await _imageService.capturePhotoLocally(widget.folderName);
        await File(scannedImagePath).copy(savePath);

        try {
          if (mounted) setState(() => _loadingMessage = 'Компресиране и качване...');
          await _imageService.uploadPhoto(File(savePath), widget.folderName);
        } catch (e) {
          if (mounted) {
            _showMessage('Внимание: снимката не се качи в хранилището: $e');
          }
        }
      }

      scanner.close();

      if (!mounted) return;

      _refreshImageList();
      _showMessage('Документът е сканиран и запазен успешно. (${scanningResult.images.length} страници)');
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('Error during capture: $e\n$st');
      _showMessage('Грешка при сканиране: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


/// Syncs photos from S3 to local storage with a fullscreen loading overlay.
Future<void> _handleSyncFromS3(BuildContext context) async {
  if (!await checkInternetAndShowDialog(context)) return; // must come first
  if (_busy) return;

  setState(() {
    _busy = true;
    _loadingMessage = 'Синхронизиране от облака...';
  });

  try {
    final downloadCount = await _imageService.syncPhotosFromS3(
      widget.folderName,
      username: widget.username,
    );

    if (!mounted) return;

    _refreshImageList();
    _showMessage('✅ Синхронизацията е завършена. Изтеглени: $downloadCount файла.');
  } catch (e) {
    if (!mounted) return;
    _showMessage('Грешка при синхронизация: $e');
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}


  /// Shows a snackbar message to the user.
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
          onPressed: () => _handleSyncFromS3(context),
        ),
      ],
    ),
    body: Stack(
      children: [
        const BackgroundLogo(),
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF5F5FB).withValues(alpha: 0.80),
                const Color(0xFFE3F2FD).withValues(alpha: 0.80),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),

          child: Column(
            children: [
              // warning banner for image responsibility
            Material(
              color: Theme.of(context).appBarTheme.backgroundColor 
                    ?? Theme.of(context).colorScheme.surface,
              elevation: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: const Text(
                  'Отговорността за качените изображения е изцяло ваша. Моля проверявайте внимателно съдържанието преди изпращане!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),

              Expanded(
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
              return ImageGrid(
                images: images,
                extractDateLabel: _imageService.extractDateLabel,
                onDeletePressed: _handleDeletePhoto,
                onImageTap: _handleOpenImage,
              );
            },
                ),
              ),
            ],
          ),
        ),

        // Fullscreen loading overlay
        if (_busy)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _busy ? null : _handleCapturePhoto,
      tooltip: 'Сканирай документ (камера)',
      child: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.document_scanner),
    ),
  );
}

}
