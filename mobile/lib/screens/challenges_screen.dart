import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/skeleton_loader.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _data;
  List<dynamic> _leaderboard = [];
  bool _loading = true;
  bool _lbLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2 && _leaderboard.isEmpty) _loadLeaderboard();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await apiService.getChallenges();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      debugPrint('[Challenges._load] $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger les défis'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final lb = await apiService.getChallengeLeaderboard();
      if (mounted) setState(() { _leaderboard = lb; _lbLoading = false; });
    } catch (e) {
      debugPrint('[Challenges._loadLeaderboard] $e');
      if (mounted) setState(() => _lbLoading = false);
    }
  }

  int _nextLevelXp(String level) {
    switch (level) {
      case 'Rookie': return 50;
      case 'Amateur': return 150;
      case 'Semi-Pro': return 350;
      case 'Pro': return 700;
      case 'Expert': return 1200;
      default: return 1200;
    }
  }

  Future<void> _complete(String key) async {
    try {
      await apiService.completeChallenge(key);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defi complete ! XP gagne.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    final xp = summary['total_xp'] as int? ?? 0;
    // Backend returns level as an object {number, title, next}; tolerate a bare
    // string too.
    final levelObj = summary['level'];
    final level = (levelObj is Map ? levelObj['title'] : levelObj) as String? ?? 'Rookie';
    final nextLevelXp = (levelObj is Map ? levelObj['next'] as int? : null) ?? _nextLevelXp(level);
    final progress = nextLevelXp > 0 ? (xp / nextLevelXp).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(AppLocalizations.of(context).challengesAndXp),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: const Icon(Icons.today), text: AppLocalizations.of(context).daily),
            Tab(icon: const Icon(Icons.date_range), text: AppLocalizations.of(context).weekly),
            Tab(icon: const Icon(Icons.leaderboard), text: AppLocalizations.of(context).ranking),
          ],
        ),
      ),
      body: _loading
          ? const PlayerListSkeleton(count: 6)
          : Column(
              children: [
                _XpHeader(xp: xp, level: level, progress: progress.clamp(0.0, 1.0)),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ChallengeList(
                        challenges: (_data?['daily'] as List<dynamic>?) ?? [],
                        onComplete: _complete,
                      ),
                      _ChallengeList(
                        challenges: (_data?['weekly'] as List<dynamic>?) ?? [],
                        onComplete: _complete,
                      ),
                      _Leaderboard(entries: _leaderboard, loading: _lbLoading),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _XpHeader extends StatelessWidget {
  final int xp;
  final String level;
  final double progress;

  const _XpHeader({required this.xp, required this.level, required this.progress});

  Color _levelColor(String level) {
    switch (level) {
      case 'Amateur': return const Color(0xFF4CAF50);
      case 'Semi-Pro': return const Color(0xFF2196F3);
      case 'Pro': return const Color(0xFF9C27B0);
      case 'Expert': return const Color(0xFFFF9800);
      case 'Legende WC': return AppColors.goldBright;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, color.withValues(alpha: 0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(level, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const Spacer(),
              Text('$xp XP total', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(progress * 100).toInt()}% vers le prochain niveau',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  final List<dynamic> challenges;
  final Future<void> Function(String key) onComplete;

  const _ChallengeList({required this.challenges, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) {
      return const Center(child: Text('Aucun defi disponible', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: challenges.length,
      itemBuilder: (_, i) => _ChallengeCard(challenge: challenges[i], onComplete: onComplete),
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  final Map<String, dynamic> challenge;
  final Future<void> Function(String key) onComplete;

  const _ChallengeCard({required this.challenge, required this.onComplete});

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _completing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final done = c['completed'] as bool? ?? false;
    final xp = c['xp'] as int? ?? 0;
    final title = c['title'] as String? ?? '';
    final desc = c['description'] as String? ?? '';
    final key = c['key'] as String? ?? '';
    final icon = _icon(key);

    return Card(
      color: done ? AppColors.background : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: done
            ? const BorderSide(color: Colors.green, width: 1)
            : BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: done ? Colors.green.withValues(alpha: 0.15) : AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(done ? Icons.check_circle : icon,
                  color: done ? Colors.green : AppColors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    color: done ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: done ? TextDecoration.lineThrough : null,
                  )),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!done)
              _completing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () async {
                        setState(() => _completing = true);
                        await widget.onComplete(key);
                        if (mounted) setState(() => _completing = false);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('+$xp XP', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
            else
              Text('+$xp XP', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  IconData _icon(String key) {
    if (key.contains('login')) return Icons.login;
    if (key.contains('news')) return Icons.newspaper;
    if (key.contains('predict')) return Icons.psychology;
    if (key.contains('team') || key.contains('captain')) return Icons.sports_soccer;
    if (key.contains('player')) return Icons.person_search;
    if (key.contains('league') || key.contains('join')) return Icons.emoji_events;
    if (key.contains('chat')) return Icons.chat;
    if (key.contains('battle') || key.contains('win')) return Icons.military_tech;
    if (key.contains('top3') || key.contains('leaderboard')) return Icons.leaderboard;
    return Icons.stars;
  }
}

class _Leaderboard extends StatelessWidget {
  final List<dynamic> entries;
  final bool loading;

  const _Leaderboard({required this.entries, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (entries.isEmpty) return const Center(child: Text('Aucun classement', style: TextStyle(color: Colors.white54)));

    final medalColors = [AppColors.goldBright, const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i] as Map<String, dynamic>;
        final rank = i + 1;
        final isTop3 = rank <= 3;
        final username = e['username'] as String? ?? '?';
        final xp = e['total_xp'] as int? ?? 0;
        final levelObj = e['level'];
        final level = (levelObj is Map ? levelObj['title'] : levelObj) as String? ?? 'Rookie';

        return Card(
          color: isTop3 ? AppColors.surface : AppColors.background,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isTop3 ? BorderSide(color: medalColors[rank - 1].withValues(alpha: 0.5)) : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isTop3 ? medalColors[rank - 1].withValues(alpha: 0.2) : AppColors.surface,
              child: Text('#$rank',
                  style: TextStyle(
                      color: isTop3 ? medalColors[rank - 1] : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(level, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: Text('$xp XP',
                style: TextStyle(
                    color: isTop3 ? medalColors[rank - 1] : AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        );
      },
    );
  }
}
