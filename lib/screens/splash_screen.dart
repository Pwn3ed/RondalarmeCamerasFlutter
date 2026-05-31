import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/rondalarme_brand_title.dart';

/// Tela exibida enquanto o app valida sessão / Firebase Auth.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'splash_logo.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                const RondalarmeBrandTitle(
                  fontSize: 30,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Câmeras',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Carregando…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
