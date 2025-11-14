import 'dart:io';
import 'package:flutter/material.dart';

/// Reusable image grid widget for displaying local photos.
/// Handles image display, enlargement, and deletion callbacks.
class ImageGrid extends StatelessWidget {
  final List<File> images;
  final Function(String fileName) extractDateLabel;
  final Function(File file) onDeletePressed;
  final void Function(File previewFile, String baseName) onImageTap;

  const ImageGrid({
    super.key,
    required this.images,
    required this.extractDateLabel,
    required this.onDeletePressed,
    required this.onImageTap,
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

    // Group images by extracted date label
    final Map<String, List<File>> groups = {};
    for (final file in images) {
      final fileName = file.path.split('/').last;
      final baseName = fileName.contains('_thumb') ? fileName.replaceFirst('_thumb', '') : fileName;
      final label = extractDateLabel(baseName) as String;
      groups.putIfAbsent(label, () => []).add(file);
    }

    final groupKeys = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: groupKeys.length,
      itemBuilder: (context, gi) {
        final label = groupKeys[gi];
        final groupFiles = groups[label]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date separator with centered label
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Expanded(child: Divider(thickness: 1)),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: groupFiles.length,
              itemBuilder: (_, i) => _buildImageTile(context, groupFiles[i]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageTile(BuildContext context, File file) {
    final fileName = file.path.split('/').last;
    // baseName is the main filename (without _thumb)
    final baseName = fileName.contains('_thumb') ? fileName.replaceFirst('_thumb', '') : fileName;
    final dateLabel = extractDateLabel(baseName) as String;

    // Prefer a thumbnail file if it exists next to the main file.
    final idx = file.path.lastIndexOf('.');
    final thumbPath = idx > 0 ? '${file.path.substring(0, idx)}_thumb${file.path.substring(idx)}' : '${file.path}_thumb';
    final thumbFile = File(thumbPath);

    // If the provided file is itself a thumbnail, use it directly as preview.
    final previewFile = file.path.contains('_thumb') ? file : (thumbFile.existsSync() ? thumbFile : file);

    return GestureDetector(
      onTap: () => onImageTap(previewFile, baseName),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.file(previewFile, fit: BoxFit.cover),
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

  
}
