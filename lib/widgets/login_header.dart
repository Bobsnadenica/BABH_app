import 'package:flutter/material.dart';

/// Login page header with app logo in a circle and lock icon.
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App logo in circle
        Container(
          width: 140,
          height: 140,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.biggest.shortestSide;
                final imageSize = available * 0.9;
                return Center(
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: Image.asset(
                      'assets/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Icon(
          Icons.lock_outline,
          size: 54,
          color: Colors.white,
        ),
      ],
    );
  }
}
