import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';


class AmplifyStorageService {
  static Future<void> uploadFile(File file, String folderName) async {
    final user = await Amplify.Auth.getCurrentUser();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final key = '${user.username}/$folderName/$timestamp.jpg';
    await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      key: key,
    );
  }

  /// List objects inside [folderName] for the current user, or for [username]
  /// if provided (admin browsing other users).
  static Future<List<StorageItem>> listFolder(String folderName, {String? username}) async {
    final user = username ?? (await Amplify.Auth.getCurrentUser()).username;
    final prefix = '$user/$folderName/';
    final result = await Amplify.Storage.list(path: prefix).result;
    return result.items;
  }

  /// List top-level user prefixes by scanning object keys and extracting the
  /// first path segment. This is used by admins to discover existing user
  /// spaces. Note: this reads available listed objects and may need paging for
  /// large buckets.
  static Future<List<String>> listAllUserPrefixes() async {
    final result = await Amplify.Storage.list(path: '').result;
    final prefixes = <String>{};
    for (final item in result.items) {
      final key = item.key;
      final first = key.split('/').first;
      if (first.isNotEmpty) prefixes.add(first);
    }
    return prefixes.toList();
  }

  /// List folder names (second path segment) for a specific [username].
  /// Example: for keys like 'alice/Входящ Контрол/2025-01-01_1.jpg', this returns
  /// ['Входящ Контрол', ...]. Returned list is unique and unordered.
  static Future<List<String>> listUserFolders(String username) async {
    final prefix = '$username/';
    final result = await Amplify.Storage.list(path: prefix).result;
    final folders = <String>{};
    for (final item in result.items) {
      final key = item.key; // non-null
      final parts = key.split('/');
      if (parts.length >= 2) {
        final folder = parts[1];
        if (folder.isNotEmpty) folders.add(folder);
      }
    }
    return folders.toList();
  }

  static Future<void> downloadFile(String key, File destination) async {
    await Amplify.Storage.downloadFile(
      key: key,
      localFile: AWSFile.fromPath(destination.path),
    ).result;
  }

  static Future<void> deleteFile(File file, String folderName) async {
    final user = await Amplify.Auth.getCurrentUser();
    final key = '${user.username}/$folderName/${file.path.split('/').last}';
    await Amplify.Storage.remove(key: key);
    await file.delete();
  }
}