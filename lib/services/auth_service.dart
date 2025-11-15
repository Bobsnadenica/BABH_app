import 'package:amplify_flutter/amplify_flutter.dart';

/// Service for authentication and password management operations.
/// Handles login, forgot password flow, and related Amplify Auth interactions.
class AuthService {
  static const String _logPrefix = '🔐';

  /// Attempts to sign in with username and password.
  /// Returns true if login is successful, false otherwise.
  /// Throws AuthException on authentication errors.
  Future<bool> signIn(String username, String password) async {
    try {
      // First, sign out if there's an existing session
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        await Amplify.Auth.signOut();
      }

      final result = await Amplify.Auth.signIn(
        username: username.trim(),
        password: password.trim(),
      );

      // Check if new password confirmation is required
      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithNewPassword) {
        safePrint('$_logPrefix User must confirm new password');
        return false; // Return false to signal password confirmation needed
      }

      final currentUser = await Amplify.Auth.getCurrentUser();
      safePrint('$_logPrefix ✅ Logged in as: ${currentUser.username}');
      return true;
    } on AuthException catch (e) {
      safePrint('$_logPrefix ❌ Sign in failed: ${e.message}');
      rethrow;
    }
  }

  /// Confirms sign-in with a new password.
  /// Used when Amplify requires password change on first login.
  Future<void> confirmSignInWithNewPassword(String newPassword) async {
    try {
      await Amplify.Auth.confirmSignIn(confirmationValue: newPassword);
      safePrint('$_logPrefix ✅ Password confirmed');
    } on AuthException catch (e) {
      safePrint('$_logPrefix ❌ Password confirmation failed: ${e.message}');
      rethrow;
    }
  }

  /// Gets the currently signed-in user.
  /// Returns null if no user is signed in.
  Future<AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } catch (e) {
      safePrint('$_logPrefix No user signed in');
      return null;
    }
  }

  /// Initiates the forgot password flow.
  /// Sends a reset code to the user's email.
  Future<void> resetPassword(String username) async {
    try {
      await Amplify.Auth.resetPassword(username: username.trim());
      safePrint('$_logPrefix ✅ Password reset initiated for $username');
    } on AuthException catch (e) {
      safePrint('$_logPrefix ❌ Password reset failed: ${e.message}');
      rethrow;
    }
  }

  /// Confirms password reset with a code and new password.
  /// Code is typically sent to user's email.
  Future<void> confirmResetPassword({
    required String username,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: username.trim(),
        newPassword: newPassword.trim(),
        confirmationCode: confirmationCode.trim(),
      );
      safePrint('$_logPrefix ✅ Password reset confirmed');
    } on AuthException catch (e) {
      safePrint('$_logPrefix ❌ Password reset confirmation failed: ${e.message}');
      rethrow;
    }
  }

  /// Checks if cooldown has passed since the last forgot password request.
  /// Returns true if enough time has passed, false if still in cooldown.
  bool canRequestPasswordReset(DateTime? lastRequest, int cooldownSeconds) {
    if (lastRequest == null) return true;
    final now = DateTime.now();
    final diff = now.difference(lastRequest);
    return diff.inSeconds >= cooldownSeconds;
  }

  /// Calculates remaining cooldown seconds.
  /// Returns 0 if cooldown has passed.
  int getRemainingCooldown(DateTime? lastRequest, int cooldownSeconds) {
    if (lastRequest == null) return 0;
    final now = DateTime.now();
    final diff = now.difference(lastRequest);
    final remaining = cooldownSeconds - diff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
