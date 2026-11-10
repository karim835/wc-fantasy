import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

// Position badge colors
Color _positionColor(String? position) {
  switch ((position ?? '').toUpperCase()) {
    case 'GK':
      return const Color(0xFFFFC107);
    case 'DEF':
      return const Color(0xFF2196F3);
    case 'MID':
      return const Color(0xFF4CAF50);
    case 'FWD':
      return const Color(0xFFF44336);
    default:
      return const Color(0xFF9E9E9E);
  }
}

class BattleScreen extends StatefulWidget {
  final String battleId;
  const BattleScreen({super.key, required this.battleId});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  Map<String, dynamic>? _battle;
  Map<String, dynamic>? _liveScore;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBattle();
    socketService.watchBattle(widget.battleId);
    socketService.onBattleScoreUpdate((data) {
      if (mounted) {
        setState(() => _liveScore = data as Map<String, dynamic>);
      }
    });
  }

  @override
  void dispose() {
    socketService.unwatchBattle(widget.battleId);
    socketService.off('battle:score_update');
    super.dispose();
  }

  Future<void> _loadBattle() async {
    try {
      final results = await Future.wait([
        apiService.getBattle(widget.battleId),
        apiService.getLiveScore(widget.battleId),
      ]);
      if (mounted) {
        setState(() {
          _battle = results[0];
          _liveScore = results[1];
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
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final homeScore = _liveScore?['home_score'] ?? _battle?['home_score'] ?? 0;
    final awayScore = _liveScore?['away_score'] ?? _battle?['away_score'] ?? 0;
    final status = (_liveScore?['status'] ?? _battle?['status'] ?? 'scheduled') as String;
    final isCompleted = status == 'completed';

    final homePlayers = (_battle?['home_players'] as List?) ?? [];
    final awayPlayers = (_battle?['away_players'] as List?) ?? [];

    // Determine winner side for highlight
    final homeWins = isCompleted && homeScore > awayScore;
    final awayWins = isCompleted && awayScore > homeScore;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(
        title: const Text('Battle', style: TextStyle(color: Colors.white)),
        actions: [
          if (status == 'live')
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBattle,
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            // Score Board
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.surface, AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Home team
                  _TeamScoreHeader(
                    name: _battle?['home_team_name'] ?? 'Home',
                    username: _battle?['home_username'] ?? '',
                    isWinner: homeWins,
                  ),
                  // Centre score + status
                  Column(
                    children: [
                      Text(
                        '$homeScore - $awayScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'live'
                              ? Colors.red
                              : status == 'completed'
                                  ? Colors.green
                                  : AppColors.gold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Away team
                  _TeamScoreHeader(
                    name: _battle?['away_team_name'] ?? 'Away',
                    username: _battle?['away_username'] ?? '',
                    isWinner: awayWins,
                  ),
                ],
              ),
            ),

            // Column headers
            Container(
              color: const Color(0xFF162535),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _battle?['home_team_name'] ?? 'Home',
                      style: TextStyle(
                        color: homeWins ? Colors.greenAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: Text(
                      _battle?['away_team_name'] ?? 'Away',
                      style: TextStyle(
                        color: awayWins ? Colors.greenAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            // Player comparison columns
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PlayersColumn(
                      players: homePlayers,
                      isWinner: homeWins,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  Container(width: 1, color: Colors.white12),
                  Expanded(
                    child: _PlayersColumn(
                      players: awayPlayers,
                      isWinner: awayWins,
                      alignment: Alignment.centerRight,
                      mirrorLayout: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamScoreHeader extends StatelessWidget {
  final String name;
  final String username;
  final bool isWinner;

  const _TeamScoreHeader({
    required this.name,
    required this.username,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isWinner ? Colors.green : AppColors.gold,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            if (isWinner)
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.emoji_events, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: isWinner ? Colors.greenAccent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          '@$username',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _PlayersColumn extends StatelessWidget {
  final List<dynamic> players;
  final bool isWinner;
  final Alignment alignment;
  final bool mirrorLayout;

  const _PlayersColumn({
    required this.players,
    required this.isWinner,
    required this.alignment,
    this.mirrorLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isWinner ? const Color(0xFF0A2010) : AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        itemCount: players.length,
        itemBuilder: (_, i) {
          final p = players[i] as Map<String, dynamic>;
          return _PlayerCard(player: p, mirrored: mirrorLayout);
        },
      ),
    );
  }
}

class _PlayerCard extends StatefulWidget {
  final Map<String, dynamic> player;
  final bool mirrored;

  const _PlayerCard({required this.player, this.mirrored = false});

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final name = player['name'] as String? ?? '';
    final position = player['position'] as String? ?? '';
    final gwPoints = player['gw_points'] ?? 0;
    final isCaptain = player['isCaptain'] == true;
    final mirrored = widget.mirrored;

    // Stats for expanded view
    final goals = player['goals'] as int? ?? 0;
    final assists = player['assists'] as int? ?? 0;
    final yellowCards = player['yellow_cards'] as int? ?? 0;
    final redCards = player['red_cards'] as int? ?? 0;
    final minutes = player['minutes_played'] as int? ?? 0;
    final cleanSheet = player['clean_sheet'] as bool? ?? false;
    final hasStats = goals > 0 || assists > 0 || yellowCards > 0 || redCards > 0 || minutes > 0;

    final positionBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _positionColor(position),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        position.isEmpty ? '?' : position,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final captainBadge = isCaptain
        ? const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text('⭐', style: TextStyle(fontSize: 11)),
          )
        : const SizedBox.shrink();

    final pointsWidget = Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: gwPoints > 0 ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: gwPoints > 0 ? AppColors.gold : Colors.white24,
          width: 1,
        ),
      ),
      child: Text(
        '$gwPoints',
        style: TextStyle(
          color: gwPoints > 0 ? AppColors.gold : Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );

    final nameRow = Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: mirrored
            ? [captainBadge, const SizedBox(width: 2), Flexible(child: _playerNameText(name, isCaptain))]
            : [Flexible(child: _playerNameText(name, isCaptain)), captainBadge],
      ),
    );

    final cardContent = mirrored
        ? Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              pointsWidget,
              const SizedBox(width: 6),
              nameRow,
              const SizedBox(width: 4),
              positionBadge,
            ],
          )
        : Row(
            children: [
              positionBadge,
              const SizedBox(width: 4),
              nameRow,
              const SizedBox(width: 6),
              pointsWidget,
            ],
          );

    return GestureDetector(
      onTap: hasStats ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: isCaptain ? const Color(0xFF1A2F45) : const Color(0xFF111E2C),
          borderRadius: BorderRadius.circular(8),
          border: isCaptain
              ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardContent,
            if (_expanded && hasStats) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (minutes > 0) _StatChip('${minutes}min', Icons.timer, Colors.white38),
                    if (goals > 0) _StatChip('$goals buts', Icons.sports_soccer, Colors.greenAccent),
                    if (assists > 0) _StatChip('$assists passes', Icons.assist_walker, Colors.lightBlueAccent),
                    if (cleanSheet && (position == 'GK' || position == 'DEF'))
                      _StatChip('CS', Icons.shield, Colors.tealAccent),
                    if (yellowCards > 0) _StatChip('$yellowCards jaune', Icons.square, Colors.yellow),
                    if (redCards > 0) _StatChip('$redCards rouge', Icons.square, Colors.red),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _playerNameText(String name, bool isCaptain) {
    return Text(
      name,
      style: TextStyle(
        color: isCaptain ? Colors.amber[100] : Colors.white70,
        fontSize: 11,
        fontWeight: isCaptain ? FontWeight.bold : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
