import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/player_avatar.dart' show flagEmoji;

/// Fixtures + live match center. Shows a LIVE section (in-play matches) on top,
/// then matches grouped by matchday. Auto-refreshes on the `scores:updated`
/// socket event and polls every 60s as a fallback.
class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key});

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;
  Timer? _poll;

  static const _live = {'IN_PLAY', 'PAUSED'};
  static const _finishedStatuses = {'FINISHED'};

  @override
  void initState() {
    super.initState();
    _load();
    socketService.on('scores:updated', (_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    socketService.off('scores:updated');
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await apiService.getMatches();
      if (!mounted) return;
      setState(() {
        _matches = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final liveMatches = _matches.where((m) => _live.contains(m['status'])).toList();
    final rest = _matches.where((m) => !_live.contains(m['status'])).toList();

    // Group the rest by matchday (ascending).
    final byMatchday = <int, List<Map<String, dynamic>>>{};
    for (final m in rest) {
      final md = (m['matchday'] as num?)?.toInt() ?? 0;
      (byMatchday[md] ??= []).add(m);
    }
    final matchdays = byMatchday.keys.toList()..sort();

    return Scaffold(
      appBar: BrandAppBar(title: Text(l.fixtures)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _matches.isEmpty
              ? AppEmptyState(icon: Icons.event_busy, title: l.noFixtures)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (liveMatches.isNotEmpty) ...[
                        _LiveHeader(label: l.live),
                        const SizedBox(height: 8),
                        ...liveMatches.map((m) => _MatchRow(match: m, live: true)),
                        const SizedBox(height: 20),
                      ],
                      for (final md in matchdays) ...[
                        _MatchdayHeader(label: l.matchday(md)),
                        const SizedBox(height: 8),
                        ...byMatchday[md]!.map((m) => _MatchRow(
                              match: m,
                              live: false,
                              finished: _finishedStatuses.contains(m['status']),
                            )),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _LiveHeader extends StatelessWidget {
  final String label;
  const _LiveHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
      ],
    );
  }
}

class _MatchdayHeader extends StatelessWidget {
  final String label;
  const _MatchdayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold, fontSize: 14));
  }
}

class _MatchRow extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool live;
  final bool finished;
  const _MatchRow({required this.match, this.live = false, this.finished = false});

  @override
  Widget build(BuildContext context) {
    final home = match['home_team'] as String? ?? 'TBD';
    final away = match['away_team'] as String? ?? 'TBD';
    final hg = match['home_goals'];
    final ag = match['away_goals'];
    final hasScore = hg != null && ag != null;

    final kickoff = match['kickoff'] != null ? DateTime.tryParse(match['kickoff'].toString())?.toLocal() : null;
    final middle = hasScore
        ? '$hg - $ag'
        : (kickoff != null ? _fmtTime(kickoff) : 'vs');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: live ? AppColors.red.withValues(alpha: 0.6) : AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _Side(name: home, alignEnd: true)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (live ? AppColors.red : Colors.white).withValues(alpha: live ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              middle,
              style: TextStyle(
                color: live ? AppColors.red : (hasScore ? Colors.white : Colors.white70),
                fontWeight: FontWeight.bold,
                fontSize: hasScore ? 15 : 13,
              ),
            ),
          ),
          Expanded(child: _Side(name: away, alignEnd: false)),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _Side extends StatelessWidget {
  final String name;
  final bool alignEnd;
  const _Side({required this.name, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final flag = Text(flagEmoji(name), style: const TextStyle(fontSize: 20));
    final label = Flexible(
      child: Text(
        name,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd ? [label, const SizedBox(width: 8), flag] : [flag, const SizedBox(width: 8), label],
    );
  }
}
