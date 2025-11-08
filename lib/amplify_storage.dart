import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/foundation.dart';

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

  static Future<List<StorageItem>> listFolder(String folderName) async {
    final user = await Amplify.Auth.getCurrentUser();
    final prefix = '${user.username}/$folderName/';
    final result = await Amplify.Storage.list(path: prefix).result;
    return result.items;
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