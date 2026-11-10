import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class PredictionScreen extends StatefulWidget {
  final Map<String, dynamic> gameweek;
  const PredictionScreen({super.key, required this.gameweek});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _community;
  Map<String, dynamic>? _myPrediction;
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;

  // Form state
  String? _selectedScorerId;
  String? _selectedScorerName;
  String? _selectedNation;
  final _goalsCtrl = TextEditingController();
  bool _submitting = false;

  // Player search
  List<dynamic> _playerResults = [];
  bool _searchingPlayers = false;
  final _playerSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _goalsCtrl.dispose();
    _playerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final gwId = widget.gameweek['id'].toString();
      final results = await Future.wait([
        apiService.getGameweekPredictions(gwId),
        apiService.getPredictionLeaderboard(),
      ]);
      final data = results[0] as Map<String, dynamic>;
      setState(() {
        _community = data['community'] as Map<String, dynamic>?;
        _myPrediction = data['myPrediction'] as Map<String, dynamic>?;
        _leaderboard = results[1] as List<dynamic>;

        // Pre-fill form from existing prediction
        if (_myPrediction != null) {
          _selectedScorerId = _myPrediction!['predicted_top_scorer'] as String?;
          _selectedNation = _myPrediction!['predicted_winner_nation'] as String?;
          final goals = _myPrediction!['predicted_goals'];
          if (goals != null) _goalsCtrl.text = goals.toString();
        }
      });
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchPlayers(String query) async {
    if (query.length < 2) { setState(() => _playerResults = []); return; }
    setState(() => _searchingPlayers = true);
    try {
      final result = await apiService.getPlayers(search: query, limit: 8);
      setState(() => _playerResults = result['players'] as List<dynamic>? ?? []);
    } catch (e) {
      debugPrint('[Prediction._searchPlayers] $e');
    } finally {
      setState(() => _searchingPlayers = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final gwId = widget.gameweek['id'].toString();
      await apiService.submitPrediction(
        gameweekId: gwId,
        predictedTopScorer: _selectedScorerId,
        predictedWinnerNation: _selectedNation,
        predictedGoals: _goalsCtrl.text.isNotEmpty ? int.tryParse(_goalsCtrl.text) : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prédiction enregistrée !'), backgroundColor: Colors.green),
        );
        _loadData();
        _tabController.animateTo(1); // go to community tab
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  static const _nations = [
    'Morocco', 'Senegal', 'Egypt', 'Algeria', 'Tunisia', 'Ghana',
    'Ivory Coast', 'South Africa', 'France', 'England', 'Spain', 'Germany',
    'Portugal', 'Brazil', 'Argentina', 'Netherlands', 'Belgium',
    'Japan', 'South Korea', 'USA', 'Mexico', 'Canada',
  ];

  @override
  Widget build(BuildContext context) {
    final gwName = widget.gameweek['name'] ?? 'Gameweek';
    final isCompleted = widget.gameweek['status'] == 'completed';

    return Scaffold(
      appBar: BrandAppBar(
        title: Text('Prédictions — $gwName'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: AppLocalizations.of(context).myPrediction),
            Tab(text: AppLocalizations.of(context).community),
            Tab(text: AppLocalizations.of(context).ranking),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _MyPredictionTab(
                  isCompleted: isCompleted,
                  myPrediction: _myPrediction,
                  selectedScorerId: _selectedScorerId,
                  selectedScorerName: _selectedScorerName,
                  selectedNation: _selectedNation,
                  goalsCtrl: _goalsCtrl,
                  playerSearchCtrl: _playerSearchCtrl,
                  playerResults: _playerResults,
                  searchingPlayers: _searchingPlayers,
                  submitting: _submitting,
                  nations: _nations,
                  onSearchPlayers: _searchPlayers,
                  onSelectPlayer: (id, name) => setState(() {
                    _selectedScorerId = id;
                    _selectedScorerName = name;
                    _playerResults = [];
                    _playerSearchCtrl.text = name;
                  }),
                  onSelectNation: (n) => setState(() => _selectedNation = n),
                  onSubmit: _submit,
                ),
                _CommunityTab(community: _community),
                _LeaderboardTab(leaderboard: _leaderboard),
              ],
            ),
    );
  }
}

// ─── My Prediction Tab ────────────────────────────────────────────────────────

class _MyPredictionTab extends StatelessWidget {
  final bool isCompleted;
  final Map<String, dynamic>? myPrediction;
  final String? selectedScorerId;
  final String? selectedScorerName;
  final String? selectedNation;
  final TextEditingController goalsCtrl;
  final TextEditingController playerSearchCtrl;
  final List<dynamic> playerResults;
  final bool searchingPlayers;
  final bool submitting;
  final List<String> nations;
  final Function(String) onSearchPlayers;
  final Function(String, String) onSelectPlayer;
  final Function(String) onSelectNation;
  final VoidCallback onSubmit;

  const _MyPredictionTab({
    required this.isCompleted,
    required this.myPrediction,
    required this.selectedScorerId,
    required this.selectedScorerName,
    required this.selectedNation,
    required this.goalsCtrl,
    required this.playerSearchCtrl,
    required this.playerResults,
    required this.searchingPlayers,
    required this.submitting,
    required this.nations,
    required this.onSearchPlayers,
    required this.onSelectPlayer,
    required this.onSelectNation,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted && myPrediction == null) {
      return const Center(
        child: Text('Pas de prédiction soumise pour cette GW.', style: TextStyle(color: Colors.white54)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (myPrediction != null && myPrediction!['resolved'] == true)
            _ResultBanner(myPrediction: myPrediction!),
          const SizedBox(height: 8),
          _SectionLabel(icon: Icons.sports_soccer, label: 'Meilleur buteur de la GW'),
          const SizedBox(height: 8),
          TextField(
            controller: playerSearchCtrl,
            onChanged: onSearchPlayers,
            enabled: !isCompleted,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Chercher un joueur...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: searchingPlayers ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ) : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          if (playerResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: playerResults.map((p) {
                  final player = p as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    title: Text(player['name'] ?? '', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${player['position']} · ${player['club'] ?? ''}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: Text('${player['points']} pts',
                        style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                    onTap: () => onSelectPlayer(player['id'].toString(), player['name'].toString()),
                  );
                }).toList(),
              ),
            ),
          if (selectedScorerId != null && playerResults.isEmpty)
            _SelectedChip(label: playerSearchCtrl.text.isNotEmpty ? playerSearchCtrl.text : selectedScorerName ?? ''),
          const SizedBox(height: 20),
          _SectionLabel(icon: Icons.flag, label: 'Nation qui va le mieux scorer'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedNation,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              hintText: 'Choisir une nation',
              hintStyle: const TextStyle(color: Colors.white38),
            ),
            items: nations.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: isCompleted ? null : (v) { if (v != null) onSelectNation(v); },
          ),
          const SizedBox(height: 20),
          _SectionLabel(icon: Icons.scoreboard, label: 'Nombre total de buts dans la GW'),
          const SizedBox(height: 8),
          TextField(
            controller: goalsCtrl,
            enabled: !isCompleted,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ex: 14',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              suffixText: 'buts',
              suffixStyle: const TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          _BonusInfo(),
          const SizedBox(height: 24),
          if (!isCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: submitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        myPrediction != null ? 'Mettre à jour' : 'Soumettre ma prédiction',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final Map<String, dynamic> myPrediction;
  const _ResultBanner({required this.myPrediction});

  @override
  Widget build(BuildContext context) {
    final pts = myPrediction['bonus_points'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pts > 0 ? Colors.green.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pts > 0 ? Colors.greenAccent : Colors.white24),
      ),
      child: Row(
        children: [
          Icon(pts > 0 ? Icons.check_circle : Icons.cancel, color: pts > 0 ? Colors.greenAccent : Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pts > 0 ? 'Tu as gagné +$pts pts bonus !' : 'Pas de bonus cette semaine',
              style: TextStyle(color: pts > 0 ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  const _SelectedChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: AppColors.gold, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BonusInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('🎯 Bonus points', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('• Bon buteur     → +10 pts', style: TextStyle(color: Colors.white54, fontSize: 12)),
          Text('• Bonne nation   → +8 pts',  style: TextStyle(color: Colors.white54, fontSize: 12)),
          Text('• Buts exacts    → +6 pts',  style: TextStyle(color: Colors.white54, fontSize: 12)),
          Text('• Buts ±1 but    → +2 pts',  style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Community Tab ────────────────────────────────────────────────────────────

class _CommunityTab extends StatelessWidget {
  final Map<String, dynamic>? community;
  const _CommunityTab({required this.community});

  @override
  Widget build(BuildContext context) {
    if (community == null) return const Center(child: Text('Aucune donnée.', style: TextStyle(color: Colors.white54)));

    final topScorers = community!['topScorerVotes'] as List<dynamic>? ?? [];
    final nations = community!['nationVotes'] as List<dynamic>? ?? [];
    final avgGoals = community!['avgPredictedGoals'];
    final total = community!['totalPredictions'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CommunityStat(
          icon: Icons.people,
          label: 'Participants',
          value: '$total prédictions',
        ),
        const SizedBox(height: 12),
        _CommunityStat(
          icon: Icons.scoreboard,
          label: 'Buts prévus en moyenne',
          value: '$avgGoals buts',
        ),
        const SizedBox(height: 20),
        const Text('⚽ Buteur le plus prédit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...topScorers.map((s) {
          final score = s as Map<String, dynamic>;
          return _VoteBar(
            label: '${score['name']} (${score['club']})',
            votes: score['votes'] as int? ?? 0,
            total: total,
            color: AppColors.gold,
          );
        }),
        const SizedBox(height: 20),
        const Text('🏆 Nation la plus prédite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...nations.map((n) {
          final nation = n as Map<String, dynamic>;
          return _VoteBar(
            label: nation['nation'] as String,
            votes: nation['votes'] as int? ?? 0,
            total: total,
            color: const Color(0xFF66BB6A),
          );
        }),
      ],
    );
  }
}

class _CommunityStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CommunityStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  final String label;
  final int votes;
  final int total;
  final Color color;
  const _VoteBar({required this.label, required this.votes, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? votes / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))),
              Text('$votes votes (${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard Tab ──────────────────────────────────────────────────────────

class _LeaderboardTab extends StatelessWidget {
  final List<dynamic> leaderboard;
  const _LeaderboardTab({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    if (leaderboard.isEmpty) {
      return const Center(child: Text('Aucune donnée.', style: TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: leaderboard.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final u = leaderboard[i] as Map<String, dynamic>;
        final rank = i + 1;
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
              SizedBox(width: 28, child: Text('#$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['username'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text('${u['correct_predictions']}/${u['total_predictions']} correctes',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Text('${u['prediction_points']} pts',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        );
      },
    );
  }
}
