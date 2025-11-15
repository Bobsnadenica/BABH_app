import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class AuthUtils {
  /// Returns the list of Cognito groups for the currently signed in user.
  ///
  /// Tries multiple token shapes (JSON-like or JWT) to be compatible with
  /// different Amplify plugin versions.
  static Future<List<String>> getUserGroups() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (session.isSignedIn && session is CognitoAuthSession) {
        String idToken = '';
        try {
          final result = session.userPoolTokensResult;
          final v = (result as dynamic).value;
          idToken = (v == null) ? '' : (v.idToken?.toString() ?? '');
        } catch (_) {}

        if (idToken.isEmpty) {
          final tokens = session.userPoolTokens;
          if (tokens != null) idToken = tokens.idToken.toString();
        }

        if (idToken.isNotEmpty) {
          final trimmed = idToken.trimLeft();
          if (trimmed.startsWith('{')) {
            try {
              final parsed = jsonDecode(idToken);
              if (parsed is Map) {
                Map<String, dynamic>? claimMap;
                if (parsed['claims'] is Map) {
                  claimMap = Map<String, dynamic>.from(parsed['claims'] as Map);
                } else if (parsed['payload'] is Map) {
                  claimMap = Map<String, dynamic>.from(parsed['payload'] as Map);
                } else {
                  claimMap = Map<String, dynamic>.from(parsed);
                }

                final groups = _extractGroupsFromMap(claimMap);
                if (groups.isNotEmpty) return groups;
              }
            } catch (_) {}
          }

          try {
            final dotCount = idToken.split('.').length - 1;
            if (dotCount == 2) {
              final parts = idToken.split('.');
              final payload = parts[1];
              final normalized = base64Url.normalize(payload);
              final decoded = utf8.decode(base64Url.decode(normalized));
              final parsed = jsonDecode(decoded);
              if (parsed is Map) {
                final map = Map<String, dynamic>.from(parsed);
                final groups = _extractGroupsFromMap(map);
                if (groups.isNotEmpty) return groups;
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return <String>[];
  }

  static List<String> _extractGroupsFromMap(Map<String, dynamic> map) {
    try {
      final groupsRaw = map['cognito:groups'] ?? map['cognito\\:groups'];
      if (groupsRaw == null) return <String>[];
      if (groupsRaw is List) return groupsRaw.map((e) => e.toString()).toList();
      if (groupsRaw is String) return [groupsRaw];
    } catch (_) {}
    return <String>[];
  }

  /// Signs out the currently signed in user.
  static Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
    } catch (_) {}
  }
}
