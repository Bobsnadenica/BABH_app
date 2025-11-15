import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:babh_dnevnicite/widgets/network_connection.dart';
import 'package:flutter/material.dart';
import '../front_page.dart';
import '../services/auth_service.dart';
import '../widgets/login_form.dart';
import '../widgets/login_header.dart';
import '../widgets/login_footer.dart';
import '../widgets/password_dialogs.dart';

/// Main login page widget.
/// Handles user authentication with support for password reset flow.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late final AuthService _authService = AuthService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _busy = false;
  DateTime? _lastForgotRequest;
  int _forgotCooldownSeconds = 0;
  Timer? _forgotCooldownTimer;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fadeController.dispose();
    _cancelForgotCooldownTimer();
    super.dispose();
  }

  void _cancelForgotCooldownTimer() {
    _forgotCooldownTimer?.cancel();
    _forgotCooldownTimer = null;
  }

  void _startForgotCooldownTimer() {
    _cancelForgotCooldownTimer();
    _forgotCooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateForgotCooldown(),
    );
  }

  void _updateForgotCooldown() {
    if (!mounted) return;
    final remaining = _authService.getRemainingCooldown(_lastForgotRequest, 120);
    setState(() => _forgotCooldownSeconds = remaining);
    if (remaining <= 0) {
      _cancelForgotCooldownTimer();
    }
  }

  /// Handles login with validation and auth service.
  Future<void> _handleLogin(String username, String password) async {
    if (!await checkInternetAndShowDialog(context)) return; // must come first
    setState(() => _busy = true);

    try {
      final success = await _authService.signIn(username, password);

      if (!mounted) return;

      if (!success) {
        // Password confirmation needed
        final newPassword = await showNewPasswordDialog(context);
        if (newPassword != null && newPassword.isNotEmpty) {
          try {
            await _authService.confirmSignInWithNewPassword(newPassword);
            if (!mounted) return;
            _navigateToHome();
          } on AuthException catch (e) {
            _showError('Грешка при промяна на паролата: ${e.message}');
          }
        } else {
          _showError('Паролата не е променена');
        }
      } else {
        _navigateToHome();
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showError('Грешка при влизане: ${e.message}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Initiates forgot password flow.
  Future<void> _handleForgotPassword() async {
    if (!await checkInternetAndShowDialog(context)) return; // must come first
    if (!_authService.canRequestPasswordReset(_lastForgotRequest, 120)) {
      _showError('Моля, изчакайте 2 минути преди да заявите отново.');
      _updateForgotCooldown();
      return;
    }

    final username = await showForgotUsernameDialog(context);
    if (username == null || username.isEmpty) return;

    try {
      setState(() => _lastForgotRequest = DateTime.now());
      _startForgotCooldownTimer();

      await _authService.resetPassword(username);
      if (!mounted) return;

      final data = await showCodeAndPasswordDialog(context);
      if (data == null) return;

      await _authService.confirmResetPassword(
        username: username,
        newPassword: data['password']!,
        confirmationCode: data['code']!,
      );

      if (mounted) {
        _showMessage('Паролата е сменена успешно.');
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showError('Грешка при промяна на паролата: ${e.message}');
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const FrontPage()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F7A4B), Color(0xFF11A680)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LoginHeader(),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: LoginForm(
                          usernameController: _userCtrl,
                          passwordController: _passCtrl,
                          formKey: _formKey,
                          isBusy: _busy,
                          obscurePassword: _obscure,
                          forgotCooldownSeconds: _forgotCooldownSeconds,
                          onLoginPressed: _handleLogin,
                          onForgotPasswordPressed: _handleForgotPassword,
                          onObscureToggle: (value) => setState(() => _obscure = value),
                        ),
                      ),
                      const SizedBox(height: 56),
                      const LoginFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
