import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../services/api_service.dart';

class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _leagues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        apiService.getProfile(),
        apiService.getLeagues(),
      ]);
      setState(() {
        _profile = (results[0] as Map<String, dynamic>)['user'];
        _leagues = results[1] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final totalPoints = _profile?['total_points'] ?? 0;
    final leagueCount = _leagues.length;
    final bestLeague = _leagues.isNotEmpty
        ? _leagues.reduce((a, b) => (a['my_points'] ?? 0) > (b['my_points'] ?? 0) ? a : b)
        : null;

    return Scaffold(
      appBar: BrandAppBar(title: const Text('Season Wrapped')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero card
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), AppColors.gold, Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    _profile?['username'] ?? 'Your Season',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text('Season Wrapped 2025/26', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(label: 'Total Points', value: totalPoints.toString(), icon: Icons.star, color: AppColors.goldBright),
              _StatCard(label: 'Leagues Joined', value: leagueCount.toString(), icon: Icons.emoji_events, color: AppColors.gold),
              _StatCard(
                label: 'Best League',
                value: bestLeague?['name'] ?? 'N/A',
                icon: Icons.military_tech,
                color: const Color(0xFFFF7043),
                small: true,
              ),
              _StatCard(
                label: 'Best Score',
                value: '${bestLeague?['my_points'] ?? 0} pts',
                icon: Icons.trending_up,
                color: const Color(0xFF66BB6A),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text('League Performance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ..._leagues.map((league) {
            final pts = league['my_points'] ?? 0;
            final max = _leagues.map((l) => (l['my_points'] ?? 0) as int).reduce((a, b) => a > b ? a : b);
            final ratio = max > 0 ? pts / max : 0.0;

            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(league['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('$pts pts', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.toDouble(),
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          // Achievements
          const Text('Achievements', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _AchievementTile(
            icon: Icons.sports_soccer,
            title: 'First Draft',
            description: 'Completed your first team draft',
            unlocked: true,
          ),
          _AchievementTile(
            icon: Icons.group,
            title: 'League Creator',
            description: 'Created your first private league',
            unlocked: leagueCount > 0,
          ),
          _AchievementTile(
            icon: Icons.auto_fix_high,
            title: 'AI Strategist',
            description: 'Used AI auto-pick or transfer suggestions',
            unlocked: false,
          ),
          _AchievementTile(
            icon: Icons.emoji_events,
            title: 'Champion',
            description: 'Finished 1st in any league',
            unlocked: false,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool small;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: small ? 14 : 20), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;

  const _AchievementTile({required this.icon, required this.title, required this.description, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: unlocked ? AppColors.goldBright : Colors.white12,
          child: Icon(icon, color: unlocked ? Colors.black : Colors.white38, size: 20),
        ),
        title: Text(title, style: TextStyle(color: unlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: TextStyle(color: unlocked ? Colors.white54 : Colors.white24, fontSize: 12)),
        trailing: unlocked ? const Icon(Icons.check_circle, color: AppColors.goldBright) : const Icon(Icons.lock, color: Colors.white24),
      ),
    );
  }
}
