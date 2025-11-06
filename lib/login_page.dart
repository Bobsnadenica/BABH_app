import 'package:flutter/material.dart';
import 'front_page.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
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
            const SnackBar(content: Text('Паролата не беше променена')),
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
        SnackBar(content: Text('Грешка при вход: ${e.message}')),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Вход')),
      body: SafeArea(
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
                    const Icon(Icons.lock_outline, size: 72, color: Colors.green),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
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
                              onPressed: _busy ? null : _tryLogin,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Вход'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _busy ? null : _forgotPasswordFlow,
                            child: const Text('Забравена парола?'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.center,
                      child: Text('Временно: testtest / testtest', style: TextStyle(color: Colors.black54)),
                    ),
                  ],
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
    final input = await _promptForUsername();
    if (input == null || input.isEmpty) return;

    final username = input.trim();

    try {
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
        SnackBar(content: Text('Грешка при промяна на парола: ${e.message}')),
      );
    }
  }

  Future<String?> _promptForUsername() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Забравена парола'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Въведете потребителско име'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отказ')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Продължи')),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _promptForCodeAndNewPassword() async {
    final codeCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Въведете код и нова парола'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Код от имейл'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Нова парола'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отказ')),
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'code': codeCtrl.text.trim(),
              'password': passCtrl.text.trim(),
            }),
            child: const Text('Потвърди'),
          ),
        ],
      ),
    );
  }
}