import 'package:flutter/material.dart';

/// Shared background logo widget displayed on logged-in pages.
/// Positioned behind content and not interactive (IgnorePointer).
class BackgroundLogo extends StatelessWidget {
  final double? opacity;

  const BackgroundLogo({
    super.key,
    this.opacity = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.9;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: opacity ?? 0.85,
            child: Image.asset(
              'assets/app_icon.png',
              width: w,
              height: w,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
