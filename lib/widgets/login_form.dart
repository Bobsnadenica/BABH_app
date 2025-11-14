import 'package:flutter/material.dart';

/// Callback when login button is pressed.
typedef OnLoginPressed = Future<void> Function(String username, String password);

/// Callback when forgot password is pressed.
typedef OnForgotPasswordPressed = Future<void> Function();

/// Reusable login form widget with username, password, and action buttons.
class LoginForm extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final bool isBusy;
  final bool obscurePassword;
  final int forgotCooldownSeconds;
  final OnLoginPressed onLoginPressed;
  final OnForgotPasswordPressed onForgotPasswordPressed;
  final Function(bool) onObscureToggle;

  const LoginForm({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.formKey,
    required this.isBusy,
    required this.obscurePassword,
    required this.forgotCooldownSeconds,
    required this.onLoginPressed,
    required this.onForgotPasswordPressed,
    required this.onObscureToggle,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          TextFormField(
            controller: widget.usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Потребителско име',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Въведете потребителско име' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: widget.passwordController,
            obscureText: widget.obscurePassword,
            decoration: InputDecoration(
              labelText: 'Парола',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(widget.obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => widget.onObscureToggle(!widget.obscurePassword),
              ),
            ),
            onFieldSubmitted: (_) => _handleLogin(),
            validator: (v) => (v == null || v.isEmpty) ? 'Въведете парола' : null,
          ),
          const SizedBox(height: 20),
          _buildLoginButton(),
          const SizedBox(height: 12),
          _buildForgotPasswordButton(),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ButtonStyle(
          padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          elevation: MaterialStateProperty.all(0),
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
        ),
        onPressed: widget.isBusy ? null : _handleLogin,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F7A4B), Color(0xFF11A680)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            height: 48,
            child: widget.isBusy
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
    );
  }

  Widget _buildForgotPasswordButton() {
    final isForgotDisabled = widget.isBusy || widget.forgotCooldownSeconds > 0;
    final buttonText = widget.forgotCooldownSeconds > 0
        ? 'Изчакайте (${widget.forgotCooldownSeconds}s)'
        : 'Забравена парола?';

    return TextButton(
      onPressed: isForgotDisabled ? null : () => widget.onForgotPasswordPressed(),
      child: Text(
        buttonText,
        style: const TextStyle(
          decoration: TextDecoration.underline,
          color: Colors.black87,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.black87,
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!widget.formKey.currentState!.validate()) return;
    await widget.onLoginPressed(
      widget.usernameController.text,
      widget.passwordController.text,
    );
  }
}
