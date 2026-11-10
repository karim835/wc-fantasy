import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Onboarding Screen — Flutter natif (100% GRATUIT)
/// Affiché uniquement au premier lancement de l'app.
/// Stocké dans SharedPreferences pour ne jamais re-afficher.

const _kOnboardingDone = 'onboarding_done';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();

  /// Vérifier si l'onboarding a déjà été complété
  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingDone) ?? false;
  }

  /// Marquer comme terminé
  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
  }
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Localized + brand-themed pages (built per-locale).
  List<_OnboardingPage> _buildPages(AppLocalizations l) => [
        _OnboardingPage(
          showLogo: true,
          title: l.onbTitle1,
          subtitle: l.onbSubtitle1,
          description: l.onbDesc1,
          gradientColors: const [AppColors.background, AppColors.navy],
          accentColor: AppColors.gold,
        ),
        _OnboardingPage(
          emoji: '🛠️',
          title: l.onbTitle2,
          subtitle: l.onbSubtitle2,
          description: l.onbDesc2,
          gradientColors: const [Color(0xFF16243C), AppColors.background],
          accentColor: AppColors.red,
        ),
        _OnboardingPage(
          emoji: '⚔️',
          title: l.onbTitle3,
          subtitle: l.onbSubtitle3,
          description: l.onbDesc3,
          gradientColors: const [AppColors.background, AppColors.surfaceElevated],
          accentColor: AppColors.goldBright,
        ),
        _OnboardingPage(
          emoji: '📊',
          title: l.onbTitle4,
          subtitle: l.onbSubtitle4,
          description: l.onbDesc4,
          gradientColors: const [Color(0xFF16243C), AppColors.background],
          accentColor: AppColors.red,
        ),
        _OnboardingPage(
          emoji: '🏆',
          title: l.onbTitle5,
          subtitle: l.onbSubtitle5,
          description: l.onbDesc5,
          gradientColors: const [AppColors.background, Color(0xFF3A2A12)],
          accentColor: AppColors.gold,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next(int pageCount) {
    if (_currentPage < pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OnboardingScreen.markDone();
    if (mounted) context.go('/landing');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pages = _buildPages(l);
    final accent = pages[_currentPage].accentColor;
    final onAccent = accent == AppColors.red ? Colors.white : AppColors.onGold;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: pages.length,
            itemBuilder: (_, i) => _PageView(page: pages[i], isActive: i == _currentPage),
          ),

          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: TextButton(
              onPressed: _finish,
              child: Text(l.skip, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pages.length, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? accent : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _next(pages.length),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _currentPage == pages.length - 1 ? l.start : l.next,
                        style: TextStyle(
                          color: onAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String? emoji;
  final bool showLogo;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradientColors;
  final Color accentColor;

  const _OnboardingPage({
    this.emoji,
    this.showLogo = false,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradientColors,
    required this.accentColor,
  });
}

class _PageView extends StatelessWidget {
  final _OnboardingPage page;
  final bool isActive;

  const _PageView({required this.page, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final Widget hero = page.showLogo
        ? Image.asset('assets/images/logo.png', height: 132)
        : Text(page.emoji ?? '', style: const TextStyle(fontSize: 80));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: page.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 80, 28, 160),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isActive)
                hero
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 300.ms)
              else
                hero,

              const SizedBox(height: 32),

              if (isActive)
                Text(
                  page.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                )
                    .animate()
                    .slideX(begin: 0.3, end: 0, duration: 400.ms, delay: 100.ms, curve: Curves.easeOutCubic)
                    .fadeIn(duration: 400.ms, delay: 100.ms)
              else
                Text(page.title, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1.1)),

              const SizedBox(height: 16),

              if (isActive)
                Text(
                  page.subtitle,
                  style: TextStyle(
                    color: page.accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                )
                    .animate()
                    .slideX(begin: 0.3, end: 0, duration: 400.ms, delay: 200.ms, curve: Curves.easeOutCubic)
                    .fadeIn(duration: 400.ms, delay: 200.ms)
              else
                Text(page.subtitle, style: TextStyle(color: page.accentColor, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),

              const SizedBox(height: 20),

              if (isActive)
                Text(
                  page.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15,
                    height: 1.6,
                  ),
                )
                    .animate()
                    .slideX(begin: 0.3, end: 0, duration: 400.ms, delay: 300.ms, curve: Curves.easeOutCubic)
                    .fadeIn(duration: 400.ms, delay: 300.ms)
              else
                Text(page.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, height: 1.6)),

              const SizedBox(height: 32),

              if (isActive)
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: page.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
                    .animate()
                    .scaleX(begin: 0, end: 1, duration: 500.ms, delay: 400.ms, curve: Curves.easeOutCubic)
              else
                Container(width: 60, height: 4, decoration: BoxDecoration(color: page.accentColor, borderRadius: BorderRadius.circular(2))),
            ],
          ),
        ),
      ),
    );
  }
}
