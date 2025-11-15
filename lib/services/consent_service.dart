import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsentDialog {
  /// Call this function to show the consent dialog if not accepted yet
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('consentAccepted') ?? false;

    if (accepted) return; // already accepted, do nothing

    // Show dialog
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false, // user must tap accept
      builder: (context) => AlertDialog(
        title: const Text('Политика за поверителност'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'FIX URLS!!!!!!!!Моля, прочетете и приемете нашата Политика за поверителност и Общи условия, за да използвате приложението.',
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _launchUrl('https://yourdomain.com/privacy'),
              child: const Text('Политика за поверителност'),
            ),
            TextButton(
              onPressed: () => _launchUrl('https://yourdomain.com/terms'),
              child: const Text('Общи условия'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await prefs.setBool('consentAccepted', true);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Приемам'),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
