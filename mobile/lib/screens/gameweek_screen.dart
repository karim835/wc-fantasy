import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/player_avatar.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_empty_state.dart';
import '../l10n/app_localizations.dart';

class GameweekScreen extends ConsumerStatefulWidget {
  const GameweekScreen({super.key});

  @override
  ConsumerState<GameweekScreen> createState() => _GameweekScreenState();
}

class _GameweekScreenState extends ConsumerState<GameweekScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _currentGw;
  List<dynamic> _teamScores = [];
  List<dynamic> _playerScores = [];
  Map<String, dynamic>? _breakdown;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Real-time: refresh scores when gameweek points are updated
    socketService.on('gameweek:points_updated', (_) {
      if (mounted) _loadData();
    });
    socketService.on('gameweek:finished', (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    socketService.off('gameweek:points_updated');
    socketService.off('gameweek:finished');
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Show cached data immediately
      final cachedGw = await cacheService.get('gw:current') as Map<String, dynamic>?;
      if (cachedGw != null && mounted) {
        final gwId = cachedGw['id']?.toString();
        final cachedTeam = gwId != null ? await cacheService.get('gw:team_scores:$gwId') as List? : null;
        final cachedPlayer = gwId != null ? await cacheService.get('gw:player_scores:$gwId') as List? : null;
      setState(() {
        _currentGw = cachedGw;
        _teamScores = cachedTeam ?? [];
        _playerScores = cachedPlayer ?? [];
        _isLoading = false;
      });
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        apiService.getCurrentGameweek(),
        apiService.getGameweeks(),
      ]);
      _currentGw = results[0] as Map<String, dynamic>?;
      // results[1] was _allGw, which is now removed as it was unused.

      if (_currentGw != null) {
        final gwId = _currentGw!['id'].toString();
        final scores = await Future.wait([
          apiService.getGameweekTeamScores(gwId),
          apiService.getGameweekPlayerScores(gwId),
        ]);
        _teamScores = (scores[0] as List?) ?? [];
        _playerScores = (scores[1] as List?) ?? [];
        final bd = await apiService.getGameweekBreakdown(gwId).catchError((_) => <String, dynamic>{});
        _breakdown = bd.isEmpty ? null : bd;
        cacheService.set('gw:current', _currentGw);
        cacheService.set('gw:team_scores:$gwId', _teamScores);
        cacheService.set('gw:player_scores:$gwId', _playerScores);
      }
    } catch (e) {
      if (cachedGw == null) _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAdminAction(String action) async {
    final gwId = _currentGw?['id']?.toString();
    if (gwId == null) return;
    final loc = AppLocalizations.of(context);

    if (action == 'finish') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(loc.finishGameweekTitle, style: const TextStyle(color: Colors.white)),
          content: Text(loc.finishGameweekConfirm, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(loc.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        final result = await apiService.finishGameweek(gwId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${loc.gameweekFinished} — ${result['battlesResolved']} battles'),
            backgroundColor: Colors.green,
          ));
          _loadData();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }

    if (action == 'battles') {
      final isAdmin = ref.read(isAdminProvider).value ?? false;
      final myId = ref.read(myProfileProvider).value?.id;
      // Show dialog to pick league. Admins may generate for ANY of their leagues;
      // regular users only for leagues they own (backend enforces this too).
      final allLeagues = await apiService.getLeagues();
      if (!mounted) return;
      final leagues = isAdmin
          ? allLeagues
          : allLeagues.where((l) => l['owner_id']?.toString() == myId).toList();
      if (leagues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAdmin ? loc.noLeagueAvailable : loc.mustOwnLeagueForBattles),
        ));
        return;
      }
      String? selectedLeagueId = leagues[0]['id']?.toString();
      // Pick the league, then act AFTER the dialog closes (popping via the
      // dialog's own context) — never run the request or touch the screen
      // context while the dialog route is still on the stack.
      final confirmedLeagueId = await showDialog<String>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(loc.generateBattles, style: const TextStyle(color: Colors.white)),
          content: DropdownButtonFormField<String>(
            initialValue: selectedLeagueId,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Ligue', labelStyle: TextStyle(color: Colors.white54)),
            items: leagues.map<DropdownMenuItem<String>>((l) => DropdownMenuItem(
              value: l['id']?.toString(),
              child: Text(l['name'] ?? '', style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (v) => selectedLeagueId = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(selectedLeagueId),
              child: const Text('Générer'),
            ),
          ],
        ),
      );

      if (confirmedLeagueId == null) return;
      try {
        final result = await apiService.generateBattles(gwId, confirmedLeagueId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${result['count']} battles générés'),
            backgroundColor: Colors.green,
          ));
          _loadData();
        }
      } on DioException catch (e) {
        // Surface the backend's real reason (e.g. "Need at least 2 teams")
        // instead of the raw HTTP-400 dump.
        final msg = e.response?.data?['error'] as String? ?? loc.error;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.error}: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: BrandAppBar(
        title: Text(l.gameweeks),
        actions: [
          if (_currentGw != null && _currentGw!['status'] == 'active')
            TextButton.icon(
              onPressed: () => context.push('/prediction', extra: _currentGw!),
              icon: const Icon(Icons.lightbulb_outline, color: AppColors.goldBright, size: 18),
              label: Text(l.predict, style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold)),
            ),
          // Admins get full gameweek control (finish + battles); league owners
          // get just "generate battles" for their own leagues. Build the menu
          // accordingly and only show it when there's something inside.
          if (_currentGw != null)
            Builder(builder: (_) {
              final isAdmin = ref.watch(isAdminProvider).value ?? false;
              final items = <PopupMenuEntry<String>>[
                if (isAdmin)
                  PopupMenuItem(value: 'finish', child: Row(children: [const Icon(Icons.flag, color: Colors.orange, size: 18), const SizedBox(width: 8), Text(l.finishGw, style: const TextStyle(color: Colors.white))])),
                PopupMenuItem(value: 'battles', child: Row(children: [const Icon(Icons.sports_kabaddi, color: AppColors.gold, size: 18), const SizedBox(width: 8), Text(l.generateBattles, style: const TextStyle(color: Colors.white))])),
              ];
              return PopupMenuButton<String>(
                icon: Icon(isAdmin ? Icons.admin_panel_settings_outlined : Icons.sports_kabaddi),
                tooltip: isAdmin ? 'Admin' : l.generateBattles,
                color: AppColors.surface,
                onSelected: (v) => _handleAdminAction(v),
                itemBuilder: (_) => items,
              );
            }),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: l.ranking),
            Tab(text: l.players),
            Tab(text: l.myTeamTab),
          ],
        ),
      ),
      body: _isLoading
          ? const GameweekSkeleton()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadData)
              : Column(
                  children: [
                    if (_currentGw != null) _GwBanner(gw: _currentGw!),
                    if (_currentGw == null)
                      const AppEmptyState.noHistory(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          RefreshIndicator(onRefresh: _loadData, color: AppColors.gold, child: _TeamScoresTab(scores: _teamScores)),
                          RefreshIndicator(onRefresh: _loadData, color: AppColors.gold, child: _PlayerScoresTab(scores: _playerScores)),
                          RefreshIndicator(onRefresh: _loadData, color: AppColors.gold, child: _MyBreakdownTab(breakdown: _breakdown)),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────

class _GwBanner extends StatelessWidget {
  final Map<String, dynamic> gw;
  const _GwBanner({required this.gw});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = gw['status'] ?? 'upcoming';
    final statusColor = status == 'active'
        ? Colors.greenAccent
        : status == 'completed'
            ? Colors.white54
            : AppColors.gold;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.background],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gw['name'] ?? 'Gameweek',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (gw['start_date'] != null)
                  Text(
                    _formatDate(gw['start_date']),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (gw['total_matches'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${gw['total_matches']}', style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(l.matchesLabel, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Team Scores Tab ──────────────────────────────────────────────────────────

class _TeamScoresTab extends StatelessWidget {
  final List<dynamic> scores;
  const _TeamScoresTab({required this.scores});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (scores.isEmpty) {
      return Center(
        child: Text(l.noTeamScores, style: const TextStyle(color: Colors.white54)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: scores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final s = scores[i] as Map<String, dynamic>;
        final rank = i + 1;
        return _RankCard(rank: rank, data: s);
      },
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  const _RankCard({required this.rank, required this.data});

  @override
  Widget build(BuildContext context) {
    Color rankColor = Colors.white54;
    if (rank == 1) rankColor = AppColors.goldBright;
    if (rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: rank <= 3 ? Border.all(color: rankColor.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['team_name'] ?? 'Équipe',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  data['username'] ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data['points'] ?? 0} pts',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '@${data['username'] ?? ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Player Scores Tab ────────────────────────────────────────────────────────

class _PlayerScoresTab extends StatelessWidget {
  final List<dynamic> scores;
  const _PlayerScoresTab({required this.scores});

  static const _posColors = {
    'GK': Color(0xFFFFA726),
    'DEF': Color(0xFF42A5F5),
    'MID': Color(0xFF66BB6A),
    'FWD': Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (scores.isEmpty) {
      return Center(
        child: Text(l.noPlayerScores, style: const TextStyle(color: Colors.white54)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: scores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final s = scores[i] as Map<String, dynamic>;
        final pos = s['position'] ?? 'MID';
        final posColor = _posColors[pos] ?? Colors.white54;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayerAvatar(
                    name: s['name'] as String? ?? '',
                    nationality: s['nationality'] as String?,
                    showFlag: true,
                    radius: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(pos, style: TextStyle(color: posColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(s['club'] ?? s['nationality'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${s['total_points'] ?? 0} pts', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  if (s['goals'] != null || s['assists'] != null)
                    Text(
                      '${s['goals'] ?? 0}G ${s['assists'] ?? 0}A',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(l.loadingError, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l.retry)),
        ],
      ),
    );
  }
}

// ─── My Team breakdown ──────────────────────────────────────────────────────────

class _MyBreakdownTab extends StatelessWidget {
  final Map<String, dynamic>? breakdown;
  const _MyBreakdownTab({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (breakdown == null) {
      return ListView(children: [const SizedBox(height: 80), Center(child: Text(l.noTeamInLeague, style: const TextStyle(color: Colors.white54)))]);
    }
    final players = ((breakdown!['players'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    final total = breakdown!['total'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(gradient: AppColors.cardGradient, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.gameweekTotal, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text('$total pts', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...players.map((p) => _breakdownRow(p)),
      ],
    );
  }

  Widget _breakdownRow(Map<String, dynamic> p) {
    final base = p['base_points'] ?? 0;
    final applied = p['applied_points'] ?? 0;
    final isCaptain = p['is_captain'] == true;
    final isBoost = p['is_boost'] == true;
    final goals = p['goals'] ?? 0;
    final assists = p['assists'] ?? 0;
    final cleanSheet = p['clean_sheet'] == true;
    final multiplied = applied != base;

    final bits = <String>[];
    if (goals > 0) bits.add('$goals⚽');
    if (assists > 0) bits.add('$assists🅰');
    if (cleanSheet) bits.add('🧤');
    if ((p['minutes_played'] ?? 0) > 0) bits.add("${p['minutes_played']}'");

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            width: 36, alignment: Alignment.center,
            child: Text(p['position'] as String? ?? '', style: TextStyle(color: AppColors.position(p['position'] as String? ?? 'MID'), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(p['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    if (isCaptain) const Padding(padding: EdgeInsets.only(left: 6), child: Text('C', style: TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold))),
                    if (isBoost) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.change_circle, color: AppColors.info, size: 14)),
                  ],
                ),
                if (bits.isNotEmpty) Text(bits.join('  '), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (multiplied)
            Text('$base→', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(' $applied', style: TextStyle(color: applied >= 0 ? AppColors.gold : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
