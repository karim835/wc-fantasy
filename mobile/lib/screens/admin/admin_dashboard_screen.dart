import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_app_bar.dart';
import '../../l10n/app_localizations.dart';

/// Real admin control panel — Overview / Users / Leagues / Players / Scoring.
/// Gated client-side (only reachable for admins from Settings) AND server-side
/// (every /api/admin/* route requires the admin role).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: BrandAppBar(
        title: Text(l.adminDashboard),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: l.overview),
            Tab(text: l.usersTab),
            Tab(text: l.leaguesTab),
            Tab(text: l.playersTab),
            Tab(text: l.scoringTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _OverviewTab(),
          _UsersTab(),
          _LeaguesTab(),
          _PlayersTab(),
          _ScoringTab(),
        ],
      ),
    );
  }
}

// ─── Overview ──────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await apiService.adminOverview();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    if (_error != null) {
      return _ErrorRetry(error: _error!, onRetry: _load);
    }
    final counts = (_data!['counts'] as Map).cast<String, dynamic>();
    final system = (_data!['system'] as Map).cast<String, dynamic>();
    final recent = (_data!['recentUsers'] as List?) ?? [];
    final signups = (_data!['signupsByDay'] as List?) ?? [];

    int n(String k) => int.tryParse('${counts[k]}') ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _KpiCard(label: l.totalUsers, value: n('users'), icon: Icons.people, color: AppColors.gold),
              _KpiCard(label: l.totalLeagues, value: n('leagues'), icon: Icons.emoji_events, color: AppColors.red),
              _KpiCard(label: l.totalTeams, value: n('teams'), icon: Icons.shield, color: AppColors.info),
              _KpiCard(label: l.totalPlayers, value: n('players'), icon: Icons.sports_soccer, color: AppColors.success),
              _KpiCard(label: l.totalMatches, value: n('matches'), icon: Icons.stadium, color: AppColors.goldBright),
              _KpiCard(label: l.totalBattles, value: n('battles'), icon: Icons.bolt, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 20),
          _signupsChart(l, signups),
          const SizedBox(height: 20),
          _recentUsersCard(l, recent),
          const SizedBox(height: 20),
          _systemCard(l, system),
        ],
      ),
    );
  }

  Widget _signupsChart(AppLocalizations l, List signups) {
    final maxV = signups.fold<int>(1, (m, s) {
      final c = int.tryParse('${(s as Map)['count']}') ?? 0;
      return c > m ? c : m;
    });
    return _Panel(
      title: l.signupsLast14d,
      child: signups.isEmpty
          ? const Text('—', style: TextStyle(color: Colors.white38))
          : SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: signups.map((s) {
                  final c = int.tryParse('${(s as Map)['count']}') ?? 0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$c', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                          const SizedBox(height: 2),
                          Container(
                            height: (c / maxV) * 60 + 4,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _recentUsersCard(AppLocalizations l, List recent) {
    return _Panel(
      title: l.recentUsers,
      child: Column(
        children: recent.map((u) {
          final m = (u as Map).cast<String, dynamic>();
          final isAdmin = m['role'] == 'admin';
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceElevated,
              child: Text('${m['username']}'.isNotEmpty ? '${m['username']}'[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white)),
            ),
            title: Text('${m['username']}', style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('${m['email']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: isAdmin
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)),
                    child: Text(l.roleAdmin, style: const TextStyle(color: AppColors.onGold, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _systemCard(AppLocalizations l, Map<String, dynamic> system) {
    final up = int.tryParse('${system['uptimeSeconds']}') ?? 0;
    final h = up ~/ 3600, mn = (up % 3600) ~/ 60;
    final tableCounts = ((system['tableCounts'] as Map?) ?? {}).cast<String, dynamic>();
    return _Panel(
      title: '${l.systemInfo} · ${l.dbStats}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(l.uptime, '${h}h ${mn}m'),
          _kv(l.memory, '${system['memoryRssMb']} MB'),
          _kv('Node', '${system['nodeVersion']}  ·  ${system['env']}'),
          const Divider(color: Colors.white12, height: 20),
          ...tableCounts.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('${e.value}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─── Users ───────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load([String? search]) async {
    setState(() => _loading = true);
    try {
      final res = await apiService.adminUsers(search: search);
      if (mounted) setState(() { _users = (res['users'] as List?) ?? []; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(q.trim()));
  }

  Future<void> _setRole(Map<String, dynamic> u, String role) async {
    try {
      await apiService.adminSetUserRole(u['id'] as String, role);
      _load(_searchCtrl.text.trim());
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.deleteUser, l.deleteUserConfirm('${u['username']}'));
    if (!ok) return;
    try {
      await apiService.adminDeleteUser(u['id'] as String);
      _snack(l.deleteUser);
      _load(_searchCtrl.text.trim());
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Text(message, style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).cancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context).delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _SearchField(controller: _searchCtrl, hint: l.searchUsersAdmin, onChanged: _onSearch),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : RefreshIndicator(
                  onRefresh: () => _load(_searchCtrl.text.trim()),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final u = (_users[i] as Map).cast<String, dynamic>();
                      final isAdmin = u['role'] == 'admin';
                      return Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.cardGradient,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: ListTile(
                          onTap: () => context.push('/manager/${u['id']}'),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.surfaceElevated,
                            child: Text('${u['username']}'.isNotEmpty ? '${u['username']}'[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text('${u['username']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              if (isAdmin) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(5)),
                                  child: Text(l.roleAdmin, style: const TextStyle(color: AppColors.onGold, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text('${u['email']} · ${u['total_points']} pts · ${u['league_count']} ${l.leaguesTab.toLowerCase()}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          trailing: PopupMenuButton<String>(
                            color: AppColors.surfaceElevated,
                            icon: const Icon(Icons.more_vert, color: Colors.white54),
                            onSelected: (v) {
                              if (v == 'admin') {
                                _setRole(u, 'admin');
                              } else if (v == 'user') {
                                _setRole(u, 'user');
                              } else if (v == 'delete') {
                                _delete(u);
                              }
                            },
                            itemBuilder: (_) => [
                              if (!isAdmin) PopupMenuItem(value: 'admin', child: Text(l.makeAdmin, style: const TextStyle(color: Colors.white))),
                              if (isAdmin) PopupMenuItem(value: 'user', child: Text(l.makeUser, style: const TextStyle(color: Colors.white))),
                              PopupMenuItem(value: 'delete', child: Text(l.deleteUser, style: const TextStyle(color: Colors.redAccent))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Leagues ───────────────────────────────────────────────────────────────
class _LeaguesTab extends StatefulWidget {
  const _LeaguesTab();
  @override
  State<_LeaguesTab> createState() => _LeaguesTabState();
}

class _LeaguesTabState extends State<_LeaguesTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<dynamic> _leagues = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load([String? search]) async {
    setState(() => _loading = true);
    try {
      final res = await apiService.adminLeagues(search: search);
      if (mounted) setState(() { _leagues = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(q.trim()));
  }

  Future<void> _delete(Map<String, dynamic> lg) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(l.deleteLeagueAdmin, style: const TextStyle(color: Colors.white)),
            content: Text(l.deleteLeagueConfirmAdmin('${lg['name']}'), style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await apiService.adminDeleteLeague(lg['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.deleteLeagueAdmin), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
      _load(_searchCtrl.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _SearchField(controller: _searchCtrl, hint: l.searchLeagues, onChanged: _onSearch),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : RefreshIndicator(
                  onRefresh: () => _load(_searchCtrl.text.trim()),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _leagues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final lg = (_leagues[i] as Map).cast<String, dynamic>();
                      final priv = lg['is_private'] == true;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.cardGradient,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: ListTile(
                          leading: Icon(priv ? Icons.lock : Icons.public, color: AppColors.gold),
                          title: Text('${lg['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          subtitle: Text('@${lg['owner_username'] ?? '—'} · ${lg['member_count']}/${lg['max_members']} · ${lg['status']}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _delete(lg),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Players ─────────────────────────────────────────────────────────────────
class _PlayersTab extends StatefulWidget {
  const _PlayersTab();
  @override
  State<_PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<_PlayersTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<dynamic> _players = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load([String? search]) async {
    setState(() => _loading = true);
    try {
      final res = await apiService.getPlayers(search: search, limit: 60, sort: 'points');
      if (mounted) setState(() { _players = (res['players'] as List?) ?? []; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(q.trim()));
  }

  double _toD(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  Future<void> _edit(Map<String, dynamic> p) async {
    final l = AppLocalizations.of(context);
    final priceCtrl = TextEditingController(text: _toD(p['price']).toStringAsFixed(1));
    final pointsCtrl = TextEditingController(text: '${p['points'] ?? 0}');
    final formCtrl = TextEditingController(text: _toD(p['form']).toStringAsFixed(1));
    String injury = (p['injury_status'] as String?) ?? 'fit';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l.editPlayer} · ${p['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _numField(priceCtrl, l.price)),
                const SizedBox(width: 12),
                Expanded(child: _numField(pointsCtrl, l.points)),
                const SizedBox(width: 12),
                Expanded(child: _numField(formCtrl, l.form)),
              ]),
              const SizedBox(height: 16),
              Text(l.injuryStatus, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['fit', 'doubtful', 'injured'].map((s) => ChoiceChip(
                  label: Text(s),
                  selected: injury == s,
                  onSelected: (_) => setSheet(() => injury = s),
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(color: injury == s ? AppColors.onGold : Colors.white54, fontSize: 12),
                )).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.onGold, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.save, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      try {
        await apiService.adminUpdatePlayer(p['id'] as String, {
          'price': double.tryParse(priceCtrl.text),
          'points': int.tryParse(pointsCtrl.text),
          'form': double.tryParse(formCtrl.text),
          'injury_status': injury,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.updated), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
          );
        }
        _load(_searchCtrl.text.trim());
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _SearchField(controller: _searchCtrl, hint: l.searchPlayersAdmin, onChanged: _onSearch),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _players.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final p = (_players[i] as Map).cast<String, dynamic>();
                    final injured = (p['injury_status'] != null && p['injury_status'] != 'fit');
                    return Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.cardGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: ListTile(
                        onTap: () => _edit(p),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.position(p['position'] as String?),
                          child: Text('${p['position'] ?? '?'}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        title: Text('${p['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        subtitle: Text('${_toD(p['price']).toStringAsFixed(1)}M · ${p['points'] ?? 0} pts · ${p['nationality'] ?? ''}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        trailing: injured
                            ? const Icon(Icons.local_hospital, color: Colors.redAccent, size: 18)
                            : const Icon(Icons.edit, color: Colors.white38, size: 18),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Scoring (links to existing stats-entry screen) ─────────────────────────
class _ScoringTab extends StatelessWidget {
  const _ScoringTab();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.scoreboard_outlined, color: AppColors.gold, size: 56),
            const SizedBox(height: 16),
            Text(l.manageScoring, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l.manageScoringSub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.onGold, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
              onPressed: () => context.push('/admin/stats'),
              icon: const Icon(Icons.open_in_new),
              label: Text(l.playerStatsEntry, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).retry, style: const TextStyle(color: AppColors.gold))),
        ],
      ),
    );
  }
}
