import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../widgets/player_photo.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/deadline_countdown.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _topPlayers = [];
  List<NewsArticle> _headlines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Show cached data immediately for instant render
    final cachedProfile = await cacheService.get('home:profile');
    final cachedPlayers = await cacheService.get('home:top_players');
    final cachedHeadlines = await cacheService.get('home:headlines');
    if (cachedProfile != null && mounted) {
      setState(() {
        _profile = (cachedProfile as Map<String, dynamic>)['user'];
        _topPlayers = (cachedPlayers as List<dynamic>?) ?? [];
        _headlines = ((cachedHeadlines as List<dynamic>?) ?? [])
            .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    }

    try {
      final results = await Future.wait([
        apiService.getProfile(),
        apiService.getTopPlayers(limit: 5),
        apiService.getLatestHeadlines(),
      ]);
      final profile = results[0] as Map<String, dynamic>;
      final topPlayers = results[1] as List<dynamic>;
      final headlines = results[2] as List<dynamic>;
      cacheService.set('home:profile', profile);
      cacheService.set('home:top_players', topPlayers);
      cacheService.set('home:headlines', headlines);
      if (mounted) {
        setState(() {
          _profile = profile['user'];
          _topPlayers = topPlayers;
          _headlines = headlines
              .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: HomeScreenSkeleton());
    }

    return Scaffold(
      appBar: BrandAppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 30),
            const SizedBox(width: 10),
            const Text('WC Fantasy'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.military_tech_outlined),
            tooltip: AppLocalizations.of(context).challenges,
            onPressed: () => context.push('/challenges'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: AppLocalizations.of(context).profile,
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: DeadlineCountdown()),
            const SizedBox(height: 14),
            _WelcomeCard(profile: _profile),
            const SizedBox(height: 20),
            _QuickActionsRow(),
            const SizedBox(height: 24),
            if (_headlines.isNotEmpty) ...[
              _SectionHeader(title: AppLocalizations.of(context).newsSection, icon: Icons.newspaper, route: '/news'),
              const SizedBox(height: 12),
              _NewsHeadlinesWidget(headlines: _headlines),
              const SizedBox(height: 24),
            ],
            _SectionHeader(title: AppLocalizations.of(context).topPlayers, icon: Icons.star, route: '/players'),
            const SizedBox(height: 12),
            ..._topPlayers.map((p) => _PlayerTile(player: p)),
          ],
        ),
      ),
    );
  }
}

// ─── Section header with "Voir tout" ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  const _SectionHeader({required this.title, required this.icon, required this.route});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go(route),
          child: Text(AppLocalizations.of(context).seeAll, style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        ),
      ],
    );
  }
}

// ─── News headlines widget ────────────────────────────────────────────────────

class _NewsHeadlinesWidget extends StatelessWidget {
  final List<NewsArticle> headlines;
  const _NewsHeadlinesWidget({required this.headlines});

  static const _catColors = {
    'Match': AppColors.gold,
    'Transfert': Color(0xFF66BB6A),
    'Blessure': Color(0xFFEF5350),
    'Équipe': Color(0xFFFFA726),
    'Qualif': Color(0xFFAB47BC),
    'Actu': Color(0xFF78909C),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: headlines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final article = headlines[i];
          final catColor = _catColors[article.category] ?? const Color(0xFF78909C);
          return GestureDetector(
            onTap: () => context.go('/news'),
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: catColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(article.category,
                            style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(article.timeAgo,
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.35),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(article.source,
                      style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Welcome card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _WelcomeCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(
              (profile?['username'] ?? 'U')[0].toUpperCase(),
              style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).welcomeGreeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(profile?['username'] ?? 'Player',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${profile?['total_points'] ?? 0} pts total',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final actions = [
      (l.draft, Icons.people, '/draft'),
      (l.leagues, Icons.emoji_events, '/leagues'),
      (l.news, Icons.newspaper, '/news'),
      (l.challenges, Icons.military_tech, '/challenges'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions
          .map((a) => GestureDetector(
                onTap: () => context.go(a.$3),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.$2, color: AppColors.gold, size: 26),
                    ),
                    const SizedBox(height: 6),
                    Text(a.$1, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─── Player tile ──────────────────────────────────────────────────────────────

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: PlayerPhoto(
          name: player['name'] as String? ?? '',
          photoUrl: player['photo_url'] as String?,
          nationality: player['nationality'] as String?,
          showFlag: true,
        ),
        title: Text(player['name'] ?? '',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text('${player['club'] ?? ''} · ${player['nationality'] ?? ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${player['points']} pts',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            Text('\$${player['price']}M',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
