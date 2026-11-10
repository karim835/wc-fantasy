import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Branded launch screen: animates the WC trophy logo on the navy canvas,
/// then routes to /home (if a session exists) or /login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Let the entrance animation breathe while we check for a stored session.
    final results = await Future.wait<dynamic>([
      apiService.hasSession(),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (!mounted) return;
    final hasSession = results[0] as bool;
    context.go(hasSession ? '/home' : '/landing');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 1.1,
            colors: [Color(0xFF18305A), AppColors.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 168)
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  )
                  .then(delay: 150.ms)
                  .shimmer(
                    duration: 1200.ms,
                    color: AppColors.goldBright.withValues(alpha: 0.45),
                  ),
              const SizedBox(height: 28),
              Text(
                'WC FANTASY',
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 4,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 600.ms).moveY(begin: 12, end: 0),
              const SizedBox(height: 6),
              Text(
                'World Cup 2026',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.goldBright,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 750.ms, duration: 600.ms),
              const SizedBox(height: 52),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.gold.withValues(alpha: 0.85),
                ),
              ).animate().fadeIn(delay: 1000.ms),
            ],
          ),
        ),
      ),
    );
  }
}
