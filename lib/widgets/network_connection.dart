import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

bool _isOfflineDialogShowing = false;

Future<bool> checkInternetAndShowDialog(BuildContext context) async {
  // First, check connectivity
  final connResult = await Connectivity().checkConnectivity();
  if (connResult == ConnectivityResult.none) {
    return _showOfflineDialog(context);
  }

  // Optionally: test real Internet by pinging a known server
  final hasRealInternet = await _hasRealInternet();
  if (!hasRealInternet) {
    return _showOfflineDialog(context);
  }

  return true;
}

Future<bool> _hasRealInternet() async {
  try {
    final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<bool> _showOfflineDialog(BuildContext context) async {
  if (_isOfflineDialogShowing) return false;
  if (!context.mounted) return false;

  _isOfflineDialogShowing = true;

  // Wait for the next frame to ensure context is ready
  await Future.delayed(Duration.zero);

  try {
    await showDialog(
      context: context,
      barrierDismissible: false, // Force user to acknowledge
      builder: (ctx) {
        return WillPopScope(
          // Prevent back-button dismiss
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('Липса на интернет'),
            content: const Text('Моля, включете интернет, за да продължите.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('ОК'),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    _isOfflineDialogShowing = false;
  }

  return false;
}
