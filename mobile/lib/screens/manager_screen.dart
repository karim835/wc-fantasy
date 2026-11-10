import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/player_photo.dart';

/// Read-only view of another manager: their public profile + (if a league is
/// given) their squad in that league. Reached by tapping leaderboard / member /
/// friend / rank rows.
class ManagerScreen extends StatefulWidget {
  final String userId;
  final String? leagueId;
  const ManagerScreen({super.key, required this.userId, this.leagueId});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _team;
  bool _loading = true;

  static const _order = ['GK', 'DEF', 'MID', 'FWD'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await apiService.getUserProfile(widget.userId);
      Map<String, dynamic>? team;
      if (widget.leagueId != null) {
        final fetched = await apiService.getMemberTeam(widget.leagueId!, widget.userId).catchError((_) => <String, dynamic>{});
        team = fetched.isEmpty ? null : fetched;
      }
      if (!mounted) return;
      setState(() {
        _user = profile['user'] as Map<String, dynamic>?;
        _team = team;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _playersFor(String pos) {
    final players = (_team?['players'] as List?) ?? const [];
    return players
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((p) => p['position'] == pos)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = _user?['username'] as String? ?? '';
    return Scaffold(
      appBar: BrandAppBar(title: Text(name.isEmpty ? l.manager : name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _user == null
              ? Center(child: Text(l.error, style: const TextStyle(color: Colors.white54)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _header(l),
                    const SizedBox(height: 20),
                    if (_team != null) ...[
                      Text('${_team!['name'] ?? ''} · ${_team!['formation'] ?? ''}',
                          style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      for (final pos in _order)
                        if (_playersFor(pos).isNotEmpty) _positionBlock(pos, _playersFor(pos)),
                    ] else if (widget.leagueId != null)
                      Center(child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(l.noTeamInLeague, style: const TextStyle(color: Colors.white54)),
                      )),
                  ],
                ),
    );
  }

  Widget _header(AppLocalizations l) {
    final avatarUrl = _user?['avatar_url'] as String?;
    final initial = (_user?['username'] as String? ?? 'U').characters.first.toUpperCase();
    final points = _user?['total_points'];
    final rank = _user?['rank'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.surface, AppColors.background]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.gold,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(ApiService.absoluteUrl(avatarUrl)) : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black))
                : null,
          ),
          const SizedBox(height: 12),
          Text(_user?['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (points != null) _stat('$points', l.points),
              if (rank != null) ...[const SizedBox(width: 24), _stat('#$rank', l.rank)],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );

  Widget _positionBlock(String pos, List<Map<String, dynamic>> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(pos, style: TextStyle(color: AppColors.position(pos), fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        ...players.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  PlayerPhoto(name: p['name'] as String? ?? '', photoUrl: p['photo_url'] as String?, nationality: p['nationality'] as String?, radius: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p['name'] as String? ?? '', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                  if (_team?['captain_id'] == p['id'])
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text('C', style: TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold)),
                    ),
                  Text('${p['club'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            )),
      ],
    );
  }
}
