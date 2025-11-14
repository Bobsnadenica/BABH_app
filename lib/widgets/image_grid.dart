import 'dart:io';
import 'package:flutter/material.dart';

/// Reusable image grid widget for displaying local photos.
/// Handles image display, enlargement, and deletion callbacks.
class ImageGrid extends StatelessWidget {
  final List<File> images;
  final Function(String fileName) extractDateLabel;
  final Function(File file) onDeletePressed;

  const ImageGrid({
    super.key,
    required this.images,
    required this.extractDateLabel,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
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
      itemBuilder: (_, i) => _buildImageTile(context, images[i]),
    );
  }

  Widget _buildImageTile(BuildContext context, File file) {
    final fileName = file.path.split('/').last;
    final dateLabel = extractDateLabel(fileName) as String;

    return GestureDetector(
      onTap: () => _showEnlargedImage(context, file, dateLabel),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
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
  }

  void _showEnlargedImage(BuildContext context, File file, String dateLabel) {
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
                  onDeletePressed(file);
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
    );
  }
}
