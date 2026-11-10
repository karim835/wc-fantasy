import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Branded entry screen shown to logged-out users before the login form.
/// Logo + slogan + Login / Create-account calls to action.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Signature red→navy identity, anchored on the deep canvas.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.red, AppColors.navy, AppColors.background],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Column(
              children: [
                const Spacer(flex: 3),

                // ── Logo + wordmark ──────────────────────────────────
                Image.asset('assets/images/logo.png', height: 150)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 24),
                Text(
                  'WC FANTASY',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                ).animate().fadeIn(delay: 300.ms, duration: 600.ms).moveY(begin: 12, end: 0),

                const SizedBox(height: 16),

                // ── Slogan ───────────────────────────────────────────
                Text(
                  l.slogan,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
                const SizedBox(height: 6),
                Text(
                  l.sloganSub,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.5,
                      ),
                ).animate().fadeIn(delay: 650.ms, duration: 600.ms),

                const Spacer(flex: 4),

                // ── CTAs ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.go('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.onGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(l.loginBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ),
                ).animate().fadeIn(delay: 800.ms, duration: 500.ms).moveY(begin: 16, end: 0),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => context.go('/login', extra: {'register': true}),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(l.createAccount,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ),
                ).animate().fadeIn(delay: 950.ms, duration: 500.ms).moveY(begin: 16, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
