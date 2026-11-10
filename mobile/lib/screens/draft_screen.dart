import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/league_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/player_photo.dart';
import '../widgets/pitch_view.dart';
import '../widgets/deadline_countdown.dart';
import '../l10n/app_localizations.dart';
import '../models/player.dart';
import 'player_detail_screen.dart';

class DraftScreen extends ConsumerStatefulWidget {
  const DraftScreen({super.key});

  @override
  ConsumerState<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends ConsumerState<DraftScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _players = [];
  Map<String, dynamic>? _team;
  bool _isLoading = true;
  String _selectedPosition = 'All';
  final _searchCtrl = TextEditingController();

  final _positions = ['All', 'GK', 'DEF', 'MID', 'FWD'];

  String? get _leagueId => ref.read(leagueProvider).leagues.isNotEmpty
      ? ref.read(leagueProvider).leagues.first.id
      : null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() async {
      await ref.read(leagueProvider.notifier).loadLeagues();
      _loadData();
    });

    socketService.onDraftPlayerPicked((data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${data['playerName']} was picked!')),
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    socketService.off('draft:player_picked');
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final pos = _selectedPosition == 'All' ? null : _selectedPosition;
      final search = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();

      final playersData = await apiService.getPlayers(position: pos, search: search);

      Map<String, dynamic> teamData = {};
      if (_leagueId != null) {
        teamData = await apiService.getMyTeam(_leagueId!).catchError((_) => <String, dynamic>{});
      }

      setState(() {
        _players = playersData['players'] ?? [];
        _team = teamData.isEmpty ? null : teamData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPlayer(String playerId, String playerName) async {
    if (_leagueId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejoins une ligue d\'abord pour ajouter des joueurs !'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      await apiService.pickPlayer(_leagueId!, playerId);
      socketService.emitDraftPick(_leagueId!, playerId, playerName);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).playerAddedToTeam(playerName)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        final msg = e.toString();
        String userMsg;
        if (msg.contains('404') || msg.contains('Team not found')) {
          userMsg = l.createTeamFirst;
        } else if (msg.contains('400') || msg.contains('budget')) {
          userMsg = l.insufficientBudget;
        } else if (msg.contains('already')) {
          userMsg = l.playerAlreadyInTeam;
        } else {
          userMsg = l.cannotAddPlayer;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMsg), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _autoPick() async {
    if (_leagueId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).joinLeagueFirst), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final suggestion = await apiService.autoPick(_leagueId!);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(AppLocalizations.of(context).autoPickSuggestion, style: const TextStyle(color: Colors.white)),
            content: Text(
              '${AppLocalizations.of(context).formation}: ${suggestion['suggestion']?['formation'] ?? 'N/A'}\n'
              '${AppLocalizations.of(context).expectedPoints}: ${suggestion['suggestion']?['expected_points'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🤖 Service IA non disponible pour le moment'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: const Text('Draft'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: DeadlineCountdown(compact: true)),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: AppLocalizations.of(context).howToPlay,
            onPressed: () => context.push('/rules'),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'AI Auto-Pick',
            onPressed: _autoPick,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Players'), Tab(text: 'My Team')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlayersTab(
            players: _players,
            positions: _positions,
            selectedPosition: _selectedPosition,
            searchCtrl: _searchCtrl,
            isLoading: _isLoading,
            onPositionChanged: (pos) {
              setState(() => _selectedPosition = pos);
              _loadData();
            },
            onSearch: _loadData,
            onPickPlayer: _pickPlayer,
          ),
          _TeamTab(team: _team, leagueId: _leagueId, onTeamCreated: _loadData),
        ],
      ),
    );
  }
}

class _PlayersTab extends StatelessWidget {
  final List<dynamic> players;
  final List<String> positions;
  final String selectedPosition;
  final TextEditingController searchCtrl;
  final bool isLoading;
  final ValueChanged<String> onPositionChanged;
  final VoidCallback onSearch;
  final Function(String, String) onPickPlayer;

  const _PlayersTab({
    required this.players, required this.positions, required this.selectedPosition,
    required this.searchCtrl, required this.isLoading, required this.onPositionChanged,
    required this.onSearch, required this.onPickPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search players...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: AppColors.surface,
              suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: onSearch),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: positions.map((pos) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(pos),
                selected: selectedPosition == pos,
                onSelected: (_) => onPositionChanged(pos),
                selectedColor: AppColors.gold,
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, i) {
                final p = players[i];
                final name = p['name'] as String? ?? '';
                return ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerDetailScreen(
                        player: Player.fromJson(p as Map<String, dynamic>),
                      ),
                    ),
                  ),
                  leading: PlayerPhoto(
                    name: name,
                    photoUrl: p['photo_url'] as String?,
                    nationality: p['nationality'] as String?,
                    showFlag: true,
                  ),
                  title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('${p['club']} • Form: ${p['form']}', style: const TextStyle(color: Colors.white54)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${p['price']}M', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                          Text('${p['points']} pts', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.gold),
                        onPressed: () => onPickPlayer(p['id'], p['name']),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TeamTab extends StatefulWidget {
  final Map<String, dynamic>? team;
  final String? leagueId;
  final VoidCallback? onTeamCreated;
  const _TeamTab({required this.team, this.leagueId, this.onTeamCreated});

  @override
  State<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<_TeamTab> {
  Future<void> _showCreateTeamDialog(BuildContext context) async {
    final nameCtrl = TextEditingController(text: 'Mon Équipe WC 2026');
    String formation = '4-3-3';
    final formations = ['4-3-3', '4-4-2', '3-5-2', '4-2-3-1', '5-3-2'];
    final l = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l.createMyTeam, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l.teamName,
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.gold), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Text(l.formation, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: formations.map((f) => ChoiceChip(
                  label: Text(f),
                  selected: formation == f,
                  onSelected: (_) => setModal(() => formation = f),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(color: formation == f ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                  backgroundColor: AppColors.background,
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel, style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await apiService.createTeam(widget.leagueId!, nameCtrl.text.trim(), formation);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.teamCreated), backgroundColor: Colors.green),
                    );
                  }
                  widget.onTeamCreated?.call();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.teamCreateError), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(l.create, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.team == null || widget.team!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer, size: 72, color: AppColors.gold),
              const SizedBox(height: 20),
              Text(l.emptyNoTeamTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(l.draftNoTeamSubtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              if (widget.leagueId != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l.createMyTeam, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showCreateTeamDialog(context),
                )
              else
                Text(l.joinLeagueInTab,
                    style: const TextStyle(color: Colors.orange, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final leagueId = widget.team!['league_id']?.toString() ?? widget.leagueId;
    if (leagueId == null) {
      return Center(child: Text(l.joinLeagueInTab, style: const TextStyle(color: Colors.orange)));
    }
    // Football-pitch builder: tap a position slot to pick players for it.
    return PitchView(
      team: widget.team!,
      leagueId: leagueId,
      onChanged: () => widget.onTeamCreated?.call(),
    );
  }
}
