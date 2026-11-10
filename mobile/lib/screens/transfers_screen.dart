import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class TransfersScreen extends StatefulWidget {
  final String leagueId;
  const TransfersScreen({super.key, required this.leagueId});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  Map<String, dynamic>? _team;
  Map<String, dynamic>? _playersBrowse;
  Map<String, dynamic>? _suggestions;      // Suggestions IA (endpoint /suggestions)
  bool _loading = true;
  bool _browsing = false;
  bool _loadingSuggestions = false;

  // Transfer state
  Map<String, dynamic>? _playerOut;
  Map<String, dynamic>? _riskData;          // Risk score du joueur sélectionné
  bool _loadingRisk = false;
  String _searchQuery = '';
  String? _positionFilter;

  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore && _browsing) {
      _loadMorePlayers();
    }
  }

  Future<void> _load() async {
    try {
      final team = await apiService.getMyTeam(widget.leagueId);
      if (mounted) setState(() { _team = team; _loading = false; });
      // Charger les suggestions IA en arrière-plan
      _loadSuggestions();
    } catch (e) {
      debugPrint('[Transfers._load] $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).cannotLoadTeam), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadSuggestions() async {
    if (_loadingSuggestions) return;
    setState(() => _loadingSuggestions = true);
    try {
      final data = await apiService.getTransferSuggestions(widget.leagueId);
      if (mounted) setState(() { _suggestions = data; _loadingSuggestions = false; });
    } catch (e) {
      debugPrint('[Transfers._loadSuggestions] $e');
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _loadRiskScore(String playerId) async {
    setState(() { _riskData = null; _loadingRisk = true; });
    try {
      final data = await apiService.getRiskScore(playerId);
      if (mounted) setState(() { _riskData = data; _loadingRisk = false; });
    } catch (e) {
      debugPrint('[Transfers._loadRiskScore] $e');
      if (mounted) setState(() => _loadingRisk = false);
    }
  }

  Future<void> _startBrowse(Map<String, dynamic> playerOut) async {
    setState(() {
      _playerOut = playerOut;
      _browsing = true;
      _page = 1;
      _hasMore = true;
      _playersBrowse = null;
      _riskData = null;
      _positionFilter = playerOut['position'] as String?;
    });
    await _fetchPlayers(reset: true);
    // Charger le risk score du joueur sortant
    if (playerOut['id'] != null) {
      _loadRiskScore(playerOut['id'] as String);
    }
  }

  Future<void> _fetchPlayers({bool reset = false}) async {
    if (reset) setState(() => _page = 1);
    try {
      final data = await apiService.getPlayers(
        position: _positionFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: _page,
        limit: 15,
      );
      final newPlayers = data['players'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;

      if (mounted) {
        setState(() {
          if (reset || _playersBrowse == null) {
            _playersBrowse = {'players': newPlayers, 'total': total};
          } else {
            (_playersBrowse!['players'] as List).addAll(newPlayers);
          }
          _hasMore = (_playersBrowse!['players'] as List).length < total;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadMorePlayers() async {
    setState(() { _loadingMore = true; _page++; });
    await _fetchPlayers();
  }

  Future<void> _makeTransfer(Map<String, dynamic> playerIn) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.confirmTransfer, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TransferRow(label: l.transferOut, name: _playerOut!['name'], color: Colors.red),
            const SizedBox(height: 8),
            const Icon(Icons.swap_vert, color: Colors.white54),
            const SizedBox(height: 8),
            _TransferRow(label: l.transferIn, name: playerIn['name'], color: Colors.green),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.confirm)),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await apiService.makeTransfer(widget.leagueId, _playerOut!['id'], playerIn['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.transferDoneMsg('${_playerOut!['name']}', '${playerIn['name']}')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() { _browsing = false; _playerOut = null; });
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e, l)), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Surface the backend's human message (e.g. "need 2.5 M€ more") instead of a raw exception.
  String _errorMessage(Object e, AppLocalizations l) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) return data['error'] as String;
    }
    return l.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: const Text('Transferts'),
        leading: _browsing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() { _browsing = false; _playerOut = null; }),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _browsing
              ? _BrowsePanel(
                  playerOut: _playerOut!,
                  players: (_playersBrowse?['players'] as List<dynamic>?) ?? [],
                  teamPlayerIds: _teamPlayerIds(),
                  positionFilter: _positionFilter,
                  searchQuery: _searchQuery,
                  loadingMore: _loadingMore,
                  scrollCtrl: _scrollCtrl,
                  riskData: _riskData,
                  loadingRisk: _loadingRisk,
                  onPositionFilter: (pos) {
                    setState(() { _positionFilter = pos; _page = 1; });
                    _fetchPlayers(reset: true);
                  },
                  onSearch: (q) {
                    setState(() { _searchQuery = q; _page = 1; });
                    _fetchPlayers(reset: true);
                  },
                  onPick: _makeTransfer,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.gold,
                  child: _TeamPanel(
                    team: _team,
                    suggestions: _suggestions,
                    loadingSuggestions: _loadingSuggestions,
                    onSwap: _startBrowse,
                    onRefreshSuggestions: _loadSuggestions,
                  ),
                ),
    );
  }

  Set<String> _teamPlayerIds() {
    final players = _team?['players'] as List<dynamic>? ?? [];
    return players.map((p) => p['id'] as String).toSet();
  }
}

// ─── Team Panel ───────────────────────────────────────────────────────────────

class _TeamPanel extends StatelessWidget {
  final Map<String, dynamic>? team;
  final Map<String, dynamic>? suggestions;
  final bool loadingSuggestions;
  final void Function(Map<String, dynamic>) onSwap;
  final VoidCallback onRefreshSuggestions;

  const _TeamPanel({
    required this.team,
    required this.suggestions,
    required this.loadingSuggestions,
    required this.onSwap,
    required this.onRefreshSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (team == null) {
      return Center(
        child: Text(l.noTeamInLeague, style: const TextStyle(color: Colors.white54)),
      );
    }

    final players = (team!['players'] as List<dynamic>?) ?? [];
    final rawBudget = team!['budget'];
    final budget = rawBudget is num ? rawBudget.toDouble() : double.tryParse('$rawBudget') ?? 0;
    final captainId = team!['captain_id'] as String?;

    return ListView(
      children: [
        _BudgetBanner(budget: budget),

        // ── Suggestions IA ─────────────────────────────────────────────────
        _SuggestionsPanel(
          suggestions: suggestions,
          isLoading: loadingSuggestions,
          onRefresh: onRefreshSuggestions,
        ),

        // ── Liste équipe ───────────────────────────────────────────────────
        if (players.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(l.noPlayersInTeam, style: const TextStyle(color: Colors.white54))),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: players.asMap().entries.map((e) {
                final p = e.value as Map<String, dynamic>;
                final isCaptain = p['id'] == captainId;
                return _TeamPlayerCard(player: p, isCaptain: isCaptain, onSwap: () => onSwap(p))
                    .animate(delay: Duration(milliseconds: e.key * 40))
                    .fadeIn(duration: 200.ms)
                    .slideX(begin: 0.05, end: 0, duration: 200.ms);
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Suggestions IA Panel ────────────────────────────────────────────────────

class _SuggestionsPanel extends StatelessWidget {
  final Map<String, dynamic>? suggestions;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _SuggestionsPanel({required this.suggestions, required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final list = suggestions?['suggestions'] as List? ?? suggestions?['data'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.gold, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Suggestions IA',
                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
              else
                InkWell(
                  onTap: onRefresh,
                  child: const Icon(Icons.refresh, color: Colors.white38, size: 18),
                ),
            ],
          ),
          if (!isLoading && list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppLocalizations.of(context).noSuggestions,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else if (list.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...list.take(3).map((s) {
              final out  = s['playerOut']  as String? ?? s['out']  as String? ?? '–';
              final inn  = s['playerIn']   as String? ?? s['in']   as String? ?? '–';
              final reason = s['reason']   as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.arrow_upward, color: Colors.red, size: 12),
                            const SizedBox(width: 4),
                            Text(out, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_downward, color: Colors.green, size: 12),
                            const SizedBox(width: 4),
                            Text(inn, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                          if (reason.isNotEmpty)
                            Text(reason, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _BudgetBanner extends StatelessWidget {
  final double budget;
  const _BudgetBanner({required this.budget});

  @override
  Widget build(BuildContext context) {
    final color = budget >= 10 ? Colors.green : budget >= 5 ? Colors.orange : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Text('${AppLocalizations.of(context).budgetRemaining}:', style: const TextStyle(color: Colors.white54)),
          const SizedBox(width: 8),
          Text('\$${budget.toStringAsFixed(1)}M',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          const Text('Appuie sur un joueur pour le remplacer',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TeamPlayerCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isCaptain;
  final VoidCallback onSwap;

  const _TeamPlayerCard({required this.player, required this.isCaptain, required this.onSwap});

  @override
  Widget build(BuildContext context) {
    final pos = player['position'] as String? ?? '?';
    final posColors = {'GK': Colors.orange, 'DEF': Colors.blue, 'MID': Colors.green, 'FWD': Colors.red};

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: (posColors[pos] ?? Colors.grey).withValues(alpha: 0.2),
              child: Text(pos, style: TextStyle(color: posColors[pos] ?? Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            if (isCaptain)
              Positioned(
                right: -4, top: -4,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.goldBright, shape: BoxShape.circle),
                  child: const Center(child: Text('C', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black))),
                ),
              ),
          ],
        ),
        title: Text(player['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(player['club'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.swap_horiz, color: AppColors.gold),
          onPressed: onSwap,
          tooltip: 'Remplacer',
        ),
      ),
    );
  }
}

// ─── Browse Panel ─────────────────────────────────────────────────────────────

class _BrowsePanel extends StatelessWidget {
  final Map<String, dynamic> playerOut;
  final List<dynamic> players;
  final Set<String> teamPlayerIds;
  final String? positionFilter;
  final String searchQuery;
  final bool loadingMore;
  final ScrollController scrollCtrl;
  final Map<String, dynamic>? riskData;
  final bool loadingRisk;
  final void Function(String?) onPositionFilter;
  final void Function(String) onSearch;
  final void Function(Map<String, dynamic>) onPick;

  const _BrowsePanel({
    required this.playerOut,
    required this.players,
    required this.teamPlayerIds,
    required this.positionFilter,
    required this.searchQuery,
    required this.loadingMore,
    required this.scrollCtrl,
    required this.onPositionFilter,
    required this.onSearch,
    required this.onPick,
    this.riskData,
    this.loadingRisk = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Joueur sortant + Risk Score ─────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: Colors.red.withValues(alpha: 0.12),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Sortant: ${playerOut['name']}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  Text('${playerOut['position']} · \$${playerOut['price']}M',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
              // Risk Score affiché si disponible
              if (loadingRisk)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.orange)),
                      SizedBox(width: 8),
                      Text('Analyse du risque...', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                )
              else if (riskData != null)
                _RiskScoreBar(riskData: riskData!),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un joueur...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: onSearch,
          ),
        ),

        // Position filters
        SizedBox(
          height: 40,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [null, 'GK', 'DEF', 'MID', 'FWD'].map((pos) {
              final selected = positionFilter == pos;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(pos ?? AppLocalizations.of(context).allPositions),
                  selected: selected,
                  onSelected: (_) => onPositionFilter(pos),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 4),

        Expanded(
          child: players.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: players.length + (loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == players.length) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final p = players[i] as Map<String, dynamic>;
                    final inTeam = teamPlayerIds.contains(p['id']);
                    return _BrowsePlayerCard(player: p, inTeam: inTeam, onPick: () => onPick(p));
                  },
                ),
        ),
      ],
    );
  }
}

class _BrowsePlayerCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool inTeam;
  final VoidCallback onPick;

  const _BrowsePlayerCard({required this.player, required this.inTeam, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final pos = player['position'] as String? ?? '?';
    final price = (player['price'] as num?)?.toDouble() ?? 0;
    final form = (player['form'] as num?)?.toDouble() ?? 0;
    final posColors = {'GK': Colors.orange, 'DEF': Colors.blue, 'MID': Colors.green, 'FWD': Colors.red};
    final formColor = form >= 7 ? Colors.green : form >= 5 ? Colors.orange : Colors.red;

    return Card(
      color: inTeam ? AppColors.background : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: inTeam ? const BorderSide(color: Colors.white12) : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (posColors[pos] ?? Colors.grey).withValues(alpha: 0.2),
          child: Text(pos, style: TextStyle(color: posColors[pos] ?? Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        title: Text(player['name'] ?? '',
            style: TextStyle(color: inTeam ? Colors.white38 : Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Text(player['club'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: formColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text('${AppLocalizations.of(context).form}: ${form.toStringAsFixed(1)}',
                  style: TextStyle(color: formColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        trailing: inTeam
            ? Text(AppLocalizations.of(context).inTeam, style: const TextStyle(color: Colors.white38, fontSize: 11))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${price.toStringAsFixed(1)}M',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: onPick,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    child: Text(AppLocalizations.of(context).choose),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Risk Score Bar ───────────────────────────────────────────────────────────

class _RiskScoreBar extends StatelessWidget {
  final Map<String, dynamic> riskData;
  const _RiskScoreBar({required this.riskData});

  @override
  Widget build(BuildContext context) {
    final score = (riskData['risk_score'] ?? riskData['riskScore'] ?? 0) as num;
    final level = riskData['risk_level'] ?? riskData['level'] ?? '';
    final reason = riskData['reason'] ?? riskData['summary'] ?? '';

    final color = score <= 3 ? Colors.green
        : score <= 6 ? Colors.orange
        : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: color, size: 13),
              const SizedBox(width: 5),
              Text(
                'Risque: ${level.toString().toUpperCase()} (${score.toStringAsFixed(1)}/10)',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score / 10,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(reason.toString(), style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  final String label;
  final String name;
  final Color color;
  const _TransferRow({required this.label, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ],
    );
  }
}
