import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/draft_screen.dart';
import 'screens/leagues_screen.dart';
import 'screens/battle_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/wrapped_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/admin/admin_stats_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/gameweek_screen.dart';
import 'screens/prediction_screen.dart';
import 'screens/league_detail_screen.dart';
import 'screens/players_screen.dart';
import 'screens/news_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/transfers_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/fantasy_hub_screen.dart';
import 'screens/more_hub_screen.dart';
import 'screens/nations_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/fixtures_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/manager_screen.dart';
import 'screens/compare_screen.dart';
import 'models/league.dart';
import 'services/locale_notifier.dart';
import 'theme/app_theme.dart';
import 'utils/haptics.dart';
import 'services/analytics_service.dart';
import 'widgets/offline_banner.dart';
import 'widgets/notification_overlay.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Global Flutter error handler ─────────────────────────────────────────
  // Capture toutes les erreurs Flutter (widget build, layout, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Afficher dans la console en dev
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
    // En prod, on pourrait envoyer à Sentry/Crashlytics ici
    // Crashlytics.instance.recordFlutterFatalError(details);
    debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
  };

  // Capture les erreurs async non-gérées (Dart zone errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher] $error\n$stack');
    // Crashlytics.instance.recordError(error, stack, fatal: true);
    return true; // true = erreur considérée comme traitée
  };

  analyticsService.init();
  // Init push notifications (flutter_local_notifications — gratuit)
  await pushNotificationService.init();
  // Onboarding est géré après l'inscription, pas au démarrage
  runApp(const ProviderScope(child: FantasySportsApp(showOnboarding: false)));
}

// ─── Page transition helpers ──────────────────────────────────────────────────

CustomTransitionPage<void> _slidePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}

CustomTransitionPage<void> _fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

// ─── Router ───────────────────────────────────────────────────────────────────

GoRouter _buildRouter(bool showOnboarding) => GoRouter(
  initialLocation: showOnboarding ? '/onboarding' : '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (_, state) => _fadePage(const SplashScreen(), state),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, state) => _fadePage(const OnboardingScreen(), state),
    ),
    GoRoute(
      path: '/landing',
      pageBuilder: (_, state) => _fadePage(const LandingScreen(), state),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (_, state) {
        final extra = state.extra;
        final startInRegister = extra is Map && extra['register'] == true;
        return _fadePage(LoginScreen(startInRegister: startInRegister), state);
      },
    ),
    GoRoute(
      path: '/forgot-password',
      pageBuilder: (_, state) => _slidePage(const ForgotPasswordScreen(), state),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (_, state) => _fadePage(const HomeScreen(), state),
        ),
        GoRoute(
          path: '/draft',
          pageBuilder: (_, state) => _fadePage(const DraftScreen(), state),
        ),
        GoRoute(
          path: '/leagues',
          pageBuilder: (_, state) => _fadePage(const LeaguesScreen(), state),
        ),
        GoRoute(
          path: '/leagues/:leagueId',
          pageBuilder: (_, state) => _slidePage(
            LeagueDetailScreen(league: state.extra as League),
            state,
          ),
        ),
        GoRoute(
          path: '/battle/:battleId',
          pageBuilder: (_, state) => _slidePage(
            BattleScreen(battleId: state.pathParameters['battleId']!),
            state,
          ),
        ),
        GoRoute(
          path: '/gameweeks',
          pageBuilder: (_, state) => _fadePage(const GameweekScreen(), state),
        ),
        GoRoute(
          path: '/prediction',
          pageBuilder: (_, state) => _slidePage(
            PredictionScreen(gameweek: state.extra as Map<String, dynamic>),
            state,
          ),
        ),
        GoRoute(
          path: '/players',
          pageBuilder: (_, state) => _fadePage(
            PlayersScreen(initialNationality: state.extra as String?),
            state,
          ),
        ),
        GoRoute(
          path: '/news',
          pageBuilder: (_, state) => _fadePage(const NewsScreen(), state),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (_, state) => _slidePage(const ProfileScreen(), state),
        ),
        GoRoute(
          path: '/challenges',
          pageBuilder: (_, state) => _slidePage(const ChallengesScreen(), state),
        ),
        GoRoute(
          path: '/transfers/:leagueId',
          pageBuilder: (_, state) => _slidePage(
            TransfersScreen(leagueId: state.pathParameters['leagueId']!),
            state,
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, state) => _slidePage(const SettingsScreen(), state),
        ),
        GoRoute(
          path: '/admin',
          pageBuilder: (_, state) => _slidePage(const AdminDashboardScreen(), state),
        ),
        GoRoute(
          path: '/admin/stats',
          pageBuilder: (_, state) => _slidePage(const AdminStatsScreen(), state),
        ),
        GoRoute(
          path: '/chatbot',
          pageBuilder: (_, state) => _fadePage(const ChatbotScreen(), state),
        ),
        GoRoute(
          path: '/wrapped',
          pageBuilder: (_, state) => _fadePage(const WrappedScreen(), state),
        ),
        GoRoute(
          path: '/fantasy',
          pageBuilder: (_, state) => _fadePage(const FantasyHubScreen(), state),
        ),
        GoRoute(
          path: '/more',
          pageBuilder: (_, state) => _fadePage(const MoreHubScreen(), state),
        ),
        GoRoute(
          path: '/nations',
          pageBuilder: (_, state) => _fadePage(const NationsScreen(), state),
        ),
        GoRoute(
          path: '/rules',
          pageBuilder: (_, state) => _slidePage(const RulesScreen(), state),
        ),
        GoRoute(
          path: '/fixtures',
          pageBuilder: (_, state) => _fadePage(const FixturesScreen(), state),
        ),
        GoRoute(
          path: '/friends',
          pageBuilder: (_, state) => _slidePage(const FriendsScreen(), state),
        ),
        GoRoute(
          path: '/join/:code',
          pageBuilder: (_, state) => _fadePage(
            LeaguesScreen(initialJoinCode: state.pathParameters['code']),
            state,
          ),
        ),
        GoRoute(
          path: '/manager/:userId',
          pageBuilder: (_, state) => _slidePage(
            ManagerScreen(
              userId: state.pathParameters['userId']!,
              leagueId: state.uri.queryParameters['leagueId'],
            ),
            state,
          ),
        ),
        GoRoute(
          path: '/compare',
          pageBuilder: (_, state) => _slidePage(const CompareScreen(), state),
        ),
      ],
    ),
  ],
);

// ─── App ──────────────────────────────────────────────────────────────────────

class FantasySportsApp extends StatefulWidget {
  final bool showOnboarding;
  const FantasySportsApp({super.key, this.showOnboarding = false});

  @override
  State<FantasySportsApp> createState() => _FantasySportsAppState();
}

class _FantasySportsAppState extends State<FantasySportsApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter(widget.showOnboarding);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeNotifier,
      builder: (_, __) => MaterialApp.router(
        title: 'WC Fantasy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        locale: localeNotifier.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: _router,
        builder: (context, child) => NotificationOverlay(
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(child: child ?? const SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Main shell / bottom nav ──────────────────────────────────────────────────

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _locationIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    // Fantasy hub: draft, leagues, gameweeks, players, battle, prediction, transfers
    if (location.startsWith('/fantasy') ||
        location.startsWith('/draft') ||
        location.startsWith('/leagues') ||
        location.startsWith('/battle') ||
        location.startsWith('/gameweeks') ||
        location.startsWith('/prediction') ||
        location.startsWith('/fixtures') ||
        location.startsWith('/join') ||
        location.startsWith('/transfers')) return 1;
    if (location.startsWith('/news')) return 2;
    if (location.startsWith('/chatbot')) return 3;
    // More hub: profile, players, nations, challenges, settings, wrapped, admin
    if (location.startsWith('/more') ||
        location.startsWith('/profile') ||
        location.startsWith('/players') ||
        location.startsWith('/nations') ||
        location.startsWith('/challenges') ||
        location.startsWith('/settings') ||
        location.startsWith('/wrapped') ||
        location.startsWith('/rules') ||
        location.startsWith('/friends') ||
        location.startsWith('/manager') ||
        location.startsWith('/compare') ||
        location.startsWith('/admin')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _locationIndex(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          Haptics.selection();
          switch (i) {
            case 0: context.go('/home'); break;
            case 1: context.go('/fantasy'); break;
            case 2: context.go('/news'); break;
            case 3: context.go('/chatbot'); break;
            case 4: context.go('/more'); break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: const Icon(Icons.sports_soccer),
            label: l.fantasy,
          ),
          NavigationDestination(
            icon: const Icon(Icons.newspaper_outlined),
            selectedIcon: const Icon(Icons.newspaper),
            label: l.news,
          ),
          NavigationDestination(
            icon: const Icon(Icons.smart_toy_outlined),
            selectedIcon: const Icon(Icons.smart_toy),
            label: l.aiChat,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: l.more,
          ),
        ],
      ),
    );
  }
}
