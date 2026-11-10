import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/league.dart';
import '../providers/league_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../l10n/app_localizations.dart';

class LeagueDetailScreen extends ConsumerStatefulWidget {
  final League league;
  final int initialTab;

  const LeagueDetailScreen({super.key, required this.league, this.initialTab = 0});

  @override
  ConsumerState<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends ConsumerState<LeagueDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTab);
    Future.microtask(() {
      ref.read(leagueProvider.notifier).selectLeague(widget.league.id);
      ref.read(leagueProvider.notifier).loadLeaderboard(widget.league.id);
    });
    socketService.joinLeague(widget.league.id);
  }

  @override
  void dispose() {
    socketService.leaveLeague(widget.league.id);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leagueProvider);
    final league = state.selectedLeague ?? widget.league;
    final leaderboard = state.leaderboard;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(league.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l.transfers,
            onPressed: () => context.push('/transfers/${league.id}'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: const Icon(Icons.info_outline),        text: l.leagueInfoTab),
            Tab(icon: const Icon(Icons.emoji_events),        text: l.leagueRankingTab),
            Tab(icon: const Icon(Icons.people),              text: l.members),
            Tab(icon: const Icon(Icons.sports_kabaddi),      text: l.battles),
            const Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InfoTab(league: league),
          _LeaderboardTab(entries: leaderboard, leagueId: league.id),
          _MembersTab(members: league.members, leagueId: league.id, ownerId: league.ownerId),
          _BattlesTab(leagueId: league.id),
          _ChatTab(leagueId: league.id),
        ],
      ),
    );
  }
}

// ─── Info Tab ─────────────────────────────────────────────────────────────────

class _InfoTab extends ConsumerWidget {
  final League league;
  const _InfoTab({required this.league});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final myId = ref.watch(currentUserProvider)?.id;
    final amOwner = myId != null && myId == league.ownerId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.surface, AppColors.gold]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(league.initials, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                Text(league.name, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _InfoRow(label: l.status, value: league.status.toUpperCase(), valueColor: league.isActive ? Colors.greenAccent : Colors.grey),
        _InfoRow(label: l.type, value: league.isPrivate ? l.privateLabel : l.publicLabel),
        _InfoRow(label: l.members, value: '${league.memberCount} / ${league.maxMembers}'),
        if (league.season != null) _InfoRow(label: l.season, value: league.season!),
        _InfoRow(label: l.myPoints, value: '${league.myPoints} pts', valueColor: AppColors.gold),
        if (league.inviteCode != null) ...[
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Text(l.leagueCode, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(league.inviteCode!,
                    style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white54),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: league.inviteCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.codeCopied), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_2, color: Colors.white54),
                      tooltip: l.shareLeague,
                      onPressed: () => _openShareSheet(context, l),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openShareSheet(context, l),
              icon: const Icon(Icons.ios_share),
              label: Text(l.shareLeague),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        if (amOwner)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openManageSheet(context, ref, l),
              icon: const Icon(Icons.settings_outlined),
              label: Text(l.manageLeague),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _leave(context, ref, l),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: Text(l.leaveLeague, style: const TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final ok = await _confirmDialog(context, l, l.leaveLeague, l.leaveLeagueConfirm);
    if (ok != true) return;
    try {
      await apiService.leaveLeague(league.id);
      if (context.mounted) {
        ref.invalidate(leagueProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.leftLeague), backgroundColor: AppColors.success));
        context.go('/leagues');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _openManageSheet(BuildContext context, WidgetRef ref, AppLocalizations l) {
    final nameCtrl = TextEditingController(text: league.name);
    bool isPrivate = league.isPrivate;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(l.manageLeague, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l.renameLeague,
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.gold), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.privateLabel, style: const TextStyle(color: Colors.white)),
                value: isPrivate,
                activeColor: AppColors.gold,
                onChanged: (v) => setModal(() => isPrivate = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.onGold, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await apiService.updateLeague(league.id, name: nameCtrl.text.trim(), isPrivate: isPrivate);
                      if (context.mounted) { ref.invalidate(leagueProvider); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.success), backgroundColor: AppColors.success)); context.go('/leagues'); }
                    } catch (_) {}
                  },
                  child: Text(l.save, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  label: Text(l.deleteLeague, style: const TextStyle(color: Colors.redAccent)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final ok = await _confirmDialog(context, l, l.deleteLeague, l.deleteLeagueConfirm);
                    if (ok != true) return;
                    try {
                      await apiService.deleteLeague(league.id);
                      if (context.mounted) { ref.invalidate(leagueProvider); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.deleteLeague), backgroundColor: AppColors.success)); context.go('/leagues'); }
                    } catch (_) {}
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDialog(BuildContext context, AppLocalizations l, String title, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
  }

  void _openShareSheet(BuildContext context, AppLocalizations l) {
    final code = league.inviteCode!;
    final link = 'wcfantasy://join/$code';
    final message = '${l.shareLeagueMsg}$code\n$link';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(l.scanToJoin, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: QrImageView(
                  data: link,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(code, style: const TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 6)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.codeCopied), duration: const Duration(seconds: 1)));
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(l.copyCode),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Share.share(message),
                      icon: const Icon(Icons.ios_share, size: 16),
                      label: Text(l.shareLeague),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.onGold, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Leaderboard Tab ──────────────────────────────────────────────────────────

class _LeaderboardTab extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String leagueId;
  const _LeaderboardTab({required this.entries, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('Aucun classement disponible', style: TextStyle(color: Colors.white54)));
    }
    final medalColors = [AppColors.goldBright, const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        final isTop3 = e.rank <= 3;
        return Card(
          color: isTop3 ? AppColors.surface : AppColors.background,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isTop3 ? BorderSide(color: medalColors[e.rank - 1].withValues(alpha: 0.5)) : BorderSide.none,
          ),
          child: ListTile(
            onTap: () => context.push('/manager/${e.id}?leagueId=$leagueId'),
            leading: CircleAvatar(
              backgroundColor: isTop3 ? medalColors[e.rank - 1].withValues(alpha: 0.2) : AppColors.surface,
              child: Text('#${e.rank}', style: TextStyle(color: isTop3 ? medalColors[e.rank - 1] : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            title: Text(e.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: Text('${e.points} pts',
                style: TextStyle(color: isTop3 ? medalColors[e.rank - 1] : AppColors.gold, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        );
      },
    );
  }
}

// ─── Members Tab ──────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final List<LeagueMember> members;
  final String leagueId;
  final String ownerId;
  const _MembersTab({required this.members, required this.leagueId, required this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return const Center(child: Text('Aucun membre', style: TextStyle(color: Colors.white54)));
    }
    final myId = ref.watch(currentUserProvider)?.id;
    final amOwner = myId != null && myId == ownerId;
    final l = AppLocalizations.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final isOwnerRow = m.userId == ownerId;
        return ListTile(
          onTap: () => context.push('/manager/${m.userId}?leagueId=$leagueId'),
          leading: CircleAvatar(
            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
            child: Text(m.initials, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),
          title: Row(
            children: [
              Flexible(child: Text(m.username, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
              if (isOwnerRow) ...[
                const SizedBox(width: 6),
                const Icon(Icons.shield, color: AppColors.goldBright, size: 14),
              ],
            ],
          ),
          trailing: (amOwner && !isOwnerRow)
              ? IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 20),
                  tooltip: l.kickMember,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text(l.kickMember, style: const TextStyle(color: Colors.white)),
                        content: Text('${l.kickMember} ${m.username}?', style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(l.kickMember),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await apiService.kickMember(leagueId, m.userId).catchError((_) {});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.username} ✓')));
                        ref.invalidate(leagueProvider);
                      }
                    }
                  },
                )
              : Text('${m.points} pts', style: const TextStyle(color: Colors.white54)),
        );
      },
    );
  }
}

// ─── Battles Tab ─────────────────────────────────────────────────────────────

class _BattlesTab extends StatefulWidget {
  final String leagueId;
  const _BattlesTab({required this.leagueId});

  @override
  State<_BattlesTab> createState() => _BattlesTabState();
}

class _BattlesTabState extends State<_BattlesTab> {
  List<dynamic> _battles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    socketService.on('battle:score_update', (data) {
      if (!mounted) return;
      final updated = data as Map<String, dynamic>;
      setState(() {
        final idx = _battles.indexWhere((b) => b['id'] == updated['id']);
        if (idx >= 0) {
          _battles[idx] = {..._battles[idx] as Map<String, dynamic>, ...updated};
        }
      });
    });
    socketService.on('battles:generated', (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    socketService.off('battle:score_update');
    socketService.off('battles:generated');
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final battles = await apiService.getBattles(widget.leagueId);
      if (mounted) setState(() { _battles = battles; _loading = false; });
    } catch (e) {
      debugPrint('[LeagueDetail._loadBattles] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_battles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_kabaddi, size: 56, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Aucun battle pour le moment', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            const Text('Générez les battles depuis la page Gameweek', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _battles.length,
        itemBuilder: (_, i) {
          final b = _battles[i] as Map<String, dynamic>;
          return _BattleCard(battle: b);
        },
      ),
    );
  }
}

class _BattleCard extends StatelessWidget {
  final Map<String, dynamic> battle;
  const _BattleCard({required this.battle});

  @override
  Widget build(BuildContext context) {
    final status = battle['status'] as String? ?? 'scheduled';
    final homeScore = battle['home_score'] ?? 0;
    final awayScore = battle['away_score'] ?? 0;
    final homeTeam = battle['home_team_name'] as String? ?? 'Home';
    final awayTeam = battle['away_team_name'] as String? ?? 'Away';
    final homeUser = battle['home_username'] as String? ?? '';
    final awayUser = battle['away_username'] as String? ?? '';
    final gw = battle['gameweek'];

    final statusColor = status == 'live'
        ? Colors.red
        : status == 'completed'
            ? Colors.green
            : AppColors.gold;

    final homeWins = status == 'completed' && homeScore > awayScore;
    final awayWins = status == 'completed' && awayScore > homeScore;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: status == 'live' ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final battleId = battle['id']?.toString();
          if (battleId != null) context.push('/battle/$battleId');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // GW + status row
              Row(
                children: [
                  if (gw != null)
                    Text('GW $gw', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Score row
              Row(
                children: [
                  // Home
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(homeTeam,
                            style: TextStyle(
                                color: homeWins ? Colors.greenAccent : Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('@$homeUser', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Score
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (homeWins) const Icon(Icons.emoji_events, color: AppColors.goldBright, size: 14),
                        Text(
                          status == 'scheduled' ? 'vs' : '$homeScore - $awayScore',
                          style: TextStyle(
                            color: status == 'scheduled' ? Colors.white38 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (awayWins) const Icon(Icons.emoji_events, color: AppColors.goldBright, size: 14),
                      ],
                    ),
                  ),
                  // Away
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(awayTeam,
                            style: TextStyle(
                                color: awayWins ? Colors.greenAccent : Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('@$awayUser', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chat Tab ─────────────────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  final String leagueId;
  const _ChatTab({required this.leagueId});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _sending = false;
  int _online = 0;
  bool _peerTyping = false;
  Timer? _typingClear;
  Timer? _typingThrottle;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Listen to real-time messages via socket
    socketService.on('chat:message', (data) {
      if (!mounted) return;
      final msg = data as Map<String, dynamic>;
      if (msg['league_id'] == widget.leagueId) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });
    socketService.on('league:presence', (data) {
      if (!mounted) return;
      final online = (data is Map ? data['online'] : null) as List?;
      if (online != null) setState(() => _online = online.length);
    });
    socketService.on('chat:typing', (_) {
      if (!mounted) return;
      setState(() => _peerTyping = true);
      _typingClear?.cancel();
      _typingClear = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _peerTyping = false);
      });
    });
  }

  void _onTyping() {
    // Throttle outgoing typing events to ~1/2s.
    if (_typingThrottle?.isActive ?? false) return;
    _typingThrottle = Timer(const Duration(seconds: 2), () {});
    socketService.emit('chat:typing', {'leagueId': widget.leagueId});
  }

  @override
  void dispose() {
    socketService.off('chat:message');
    socketService.off('league:presence');
    socketService.off('chat:typing');
    _typingClear?.cancel();
    _typingThrottle?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await apiService.getChatMessages(widget.leagueId);
      setState(() {
        _messages = msgs.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      debugPrint('[LeagueDetail._loadMessages] $e');
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      await apiService.sendChatMessage(widget.leagueId, text);
      // Completion via socket event — no need to add manually
    } catch (_) {
      // Re-add text on failure
      _msgCtrl.text = text;
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        if (_online > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.surface,
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(l.onlineCount(_online), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('Soyez le premier à écrire !', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
                    ),
        ),
        if (_peerTyping)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 4),
              child: Text(l.someoneTyping, style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          ),
        _ChatInput(ctrl: _msgCtrl, sending: _sending, onSend: _send, onTyping: _onTyping),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final username = message['username'] as String? ?? '?';
    final text = message['message'] as String? ?? '';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final time = _formatTime(message['created_at'] as String?);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
            child: Text(initial, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(username, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback? onTyping;
  const _ChatInput({required this.ctrl, required this.sending, required this.onSend, this.onTyping});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        top: 8,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              onSubmitted: (_) => onSend(),
              onChanged: (_) => onTyping?.call(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
            child: IconButton(
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send, color: Colors.black, size: 20),
              onPressed: sending ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
