import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../app_properties.dart';
import 'package:flutter/foundation.dart';

/// Global app configuration instance.
/// Initialized from schema, updated when S3 config is loaded.
Map<String, dynamic> appConfig = Map<String, dynamic>.from(appPropertiesSchema);

/// Recursively compares two maps/objects and logs all differences.
/// Fully generic - works with any nested structure.
/// Notifier with validation messages produced when S3 config differs from schema.
/// UI can listen to this to show in-app warnings to the user.
final ValueNotifier<List<String>> configValidationMessages = ValueNotifier<List<String>>(<String>[]);

void _compareStructures(
  dynamic s3Value,
  dynamic defaultValue,
  String path,
  List<String> outMessages,
) {
  const logPrefix = '⚙️ 🔍';

  // Helper to record and log
  void _record(String msg) {
    safePrint(msg);
    outMessages.add(msg.replaceFirst('$logPrefix ', ''));
  }

  // Both are maps: recurse into all keys
  if (s3Value is Map && defaultValue is Map) {
    final s3Keys = s3Value.keys.toSet();
    final defaultKeys = defaultValue.keys.toSet();

    // Missing keys (in defaults but not S3)
    for (final key in defaultKeys.difference(s3Keys)) {
      _record('$logPrefix ⚠️ MISSING in S3: $path$key');
    }

    // Extra keys (in S3 but not defaults)
    for (final key in s3Keys.difference(defaultKeys)) {
      _record('$logPrefix ⚠️ EXTRA in S3: $path$key');
    }

    // Recurse into common keys
    for (final key in s3Keys.intersection(defaultKeys)) {
      final newPath = path.isEmpty ? '$key' : '$path.$key';
      _compareStructures(s3Value[key], defaultValue[key], newPath, outMessages);
    }
  }
  // Both are lists: compare length only (content is user data)
  else if (s3Value is List && defaultValue is List) {
    if (s3Value.length != defaultValue.length) {
      _record('$logPrefix ℹ️ List length differs at $path: S3 has ${s3Value.length}, defaults has ${defaultValue.length}');
    }
  }
  // Type mismatch
  else if (s3Value.runtimeType != defaultValue.runtimeType) {
    _record('$logPrefix ⚠️ TYPE MISMATCH at $path: S3 is ${s3Value.runtimeType}, defaults is ${defaultValue.runtimeType}');
  }
  // Value differs (scalar types)
  else if (s3Value != defaultValue) {
    _record('$logPrefix ℹ️ Value differs at $path: S3=$s3Value, default=$defaultValue');
  }
}

/// Validates config against schema and logs result.
void _validateConfigStructure(Map<String, dynamic> s3Config) {
    const logPrefix = '⚙️ 🔍';
    safePrint('$logPrefix Validating config structure...');
    final List<String> msgs = <String>[];
    _compareStructures(s3Config, appPropertiesSchema, '', msgs);
    if (msgs.isNotEmpty) {
      configValidationMessages.value = List<String>.from(msgs);
      safePrint('$logPrefix ⚠️ Config validation produced ${msgs.length} message(s)');
    } else {
      // clear any previous messages
      configValidationMessages.value = <String>[];
      safePrint('$logPrefix ✅ Config validation complete');
    }
}

/// Service for fetching and managing app configuration from S3.
class AppConfigService {
  static const String _configKey = 'app_properties.json';
  static const String _logPrefix = '⚙️';

  /// Fetches app configuration from S3 (no caching - always fetches fresh).
  static Future<Map<String, dynamic>> getConfig() async {
    try {
      safePrint('$_logPrefix Attempting to fetch app config from S3 (guest/public access)...');
      try {
        final result = await Amplify.Storage.downloadData(
          key: _configKey,
          options: StorageDownloadDataOptions(
            accessLevel: StorageAccessLevel.guest,
          ),
        ).result;
        final jsonString = utf8.decode(result.bytes);
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // Validate and update global
        _validateConfigStructure(jsonData);
        appConfig = jsonData;
        
        safePrint('$_logPrefix ✅ App config loaded from public/');
        if (jsonData['folders'] is List && (jsonData['folders'] as List).isNotEmpty) {
          safePrint('$_logPrefix → First folder: ${(jsonData['folders'] as List)[0]}');
        }
        return jsonData;
      } catch (e1) {
        safePrint('$_logPrefix ⚠️ Guest/public access failed: $e1, trying protected...');
        // Fallback to protected access level
        final result = await Amplify.Storage.downloadData(
          key: _configKey,
          options: StorageDownloadDataOptions(
            accessLevel: StorageAccessLevel.protected,
          ),
        ).result;
        final jsonString = utf8.decode(result.bytes);
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // Validate and update global
        _validateConfigStructure(jsonData);
        appConfig = jsonData;
        
        safePrint('$_logPrefix ✅ App config loaded from protected/');
        if (jsonData['folders'] is List && (jsonData['folders'] as List).isNotEmpty) {
          safePrint('$_logPrefix → First folder: ${(jsonData['folders'] as List)[0]}');
        }
        return jsonData;
      }
    } catch (e) {
      safePrint('$_logPrefix ⚠️ Failed to load app config from S3: $e');
      safePrint('$_logPrefix Using schema defaults from app_properties.dart');
      // Return defaults from schema
      return appPropertiesSchema;
    }
  }
}
