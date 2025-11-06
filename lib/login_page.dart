import 'package:flutter/material.dart';
import 'front_page.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _busy = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // Forgot password cooldown
  DateTime? _lastForgotRequest;
  int _forgotCooldownSeconds = 0;
  // Timer is nullable, so we don't import dart:async at the top unless needed
  dynamic _forgotCooldownTimer;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fadeController.dispose();
    _cancelForgotCooldownTimer();
    super.dispose();
  }

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
    _updateForgotCooldown();
  }
  void _startForgotCooldownTimer() {
    _cancelForgotCooldownTimer();
    _forgotCooldownTimer = (Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        _updateForgotCooldown();
      },
    ));
  }

  void _cancelForgotCooldownTimer() {
    if (_forgotCooldownTimer != null) {
      _forgotCooldownTimer.cancel();
      _forgotCooldownTimer = null;
    }
  }

  void _updateForgotCooldown() {
    if (_lastForgotRequest == null) {
      if (_forgotCooldownSeconds != 0) {
        setState(() {
          _forgotCooldownSeconds = 0;
        });
      }
      _cancelForgotCooldownTimer();
      return;
    }
    final now = DateTime.now();
    final diff = now.difference(_lastForgotRequest!);
    final secondsLeft = 120 - diff.inSeconds;
    if (secondsLeft > 0) {
      setState(() {
        _forgotCooldownSeconds = secondsLeft;
      });
      _startForgotCooldownTimer();
    } else {
      setState(() {
        _forgotCooldownSeconds = 0;
        _lastForgotRequest = null;
      });
      _cancelForgotCooldownTimer();
    }
  }
  Future<void> _tryLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        await Amplify.Auth.signOut();
      }
      final result = await Amplify.Auth.signIn(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // Handle "new password required" challenge
      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithNewPassword) {
        final newPassword = await _promptForNewPassword();
        if (newPassword != null && newPassword.isNotEmpty) {
          await Amplify.Auth.confirmSignIn(confirmationValue: newPassword);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Паролата не е променена')),
          );
          return;
        }
      }

      final currentUser = await Amplify.Auth.getCurrentUser();
      safePrint('✅ Logged in as: ${currentUser.username}');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FrontPage()),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка при влизане: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptForNewPassword() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Нова парола'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Въведете нова парола'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отказ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Запази'),
          ),
        ],
      ),
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
            colors: [
              Color(0xFF43e97b), // light green
              Color(0xFF38f9d7), // green-teal
              Color(0xFF11998e), // dark green
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 88,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
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
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _userCtrl,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Потребителско име',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Въведете потребителско име' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passCtrl,
                                    obscureText: _obscure,
                                    decoration: InputDecoration(
                                      labelText: 'Парола',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                        onPressed: () => setState(() => _obscure = !_obscure),
                                      ),
                                    ),
                                    onFieldSubmitted: (_) => _tryLogin(),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Въведете парола' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ButtonStyle(
                                        padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
                                        shape: MaterialStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        elevation: MaterialStateProperty.all(0),
                                        backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                        shadowColor: MaterialStateProperty.all(Colors.transparent),
                                      ),
                                      onPressed: _busy ? null : _tryLogin,
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF43e97b),
                                              Color(0xFF38f9d7),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          height: 48,
                                          child: _busy
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : const Text(
                                                  'Вход',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: (_busy || _forgotCooldownSeconds > 0) ? null : _forgotPasswordFlow,
                                    child: Text(
                                      _forgotCooldownSeconds > 0
                                          ? 'Изчакайте (${_forgotCooldownSeconds}s)'
                                          : 'Забравена парола?',
                                      style: const TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      textStyle: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 56),
                      const SizedBox(height: 8),
                      // Footer
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Text(
                            '© БАБХ Дневниците 2025',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
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

  // Forgot password: request code, then confirm with code + new password
  Future<void> _forgotPasswordFlow() async {
    // Check cooldown
    if (_lastForgotRequest != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastForgotRequest!);
      if (diff.inSeconds < 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Моля, изчакайте 2 минути преди да заявите отново.')),
        );
        _updateForgotCooldown();
        return;
      }
    }

    final input = await _promptForUsername();
    if (input == null || input.isEmpty) return;

    final username = input.trim();

    try {
      // Set cooldown
      setState(() {
        _lastForgotRequest = DateTime.now();
      });
      _updateForgotCooldown();
      await Amplify.Auth.resetPassword(username: username);
      final data = await _promptForCodeAndNewPassword();
      if (data == null) return;

      final code = data['code']!;
      final newPassword = data['password']!;
      await Amplify.Auth.confirmResetPassword(
        username: username,
        newPassword: newPassword,
        confirmationCode: code,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Паролата е сменена успешно.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка при промяна на паролата: ${e.message}')),
      );
    }
  }

  Future<String?> _promptForUsername() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Забравена парола',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Въведете потребителско име',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    elevation: MaterialStateProperty.all(0),
                    backgroundColor: MaterialStateProperty.all(Colors.transparent),
                    shadowColor: MaterialStateProperty.all(Colors.transparent),
                  ),
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF43e97b),
                          Color(0xFF38f9d7),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      height: 48,
                      child: const Text(
                        'Продължи',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Отказ',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, String>?> _promptForCodeAndNewPassword() async {
    final codeCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Въведете код и нова парола',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  labelText: 'Код от имейл',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Нова парола',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    elevation: MaterialStateProperty.all(0),
                    backgroundColor: MaterialStateProperty.all(Colors.transparent),
                    shadowColor: MaterialStateProperty.all(Colors.transparent),
                  ),
                  onPressed: () => Navigator.pop(context, {
                    'code': codeCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                  }),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF43e97b),
                          Color(0xFF38f9d7),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      height: 48,
                      child: const Text(
                        'Потвърди',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Отказ',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}