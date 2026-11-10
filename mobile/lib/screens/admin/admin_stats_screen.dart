import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../widgets/player_avatar.dart';

/// Admin screen for manually entering player stats per gameweek.
/// Accessible from settings when the user has admin role.
/// Uses the existing backend endpoints (no extra cost, free).
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  List<dynamic> _gameweeks = [];
  List<dynamic> _players   = [];
  dynamic _selectedGw;
  bool _loadingGws    = true;
  bool _loadingPlayers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGameweeks();
  }

  Future<void> _loadGameweeks() async {
    try {
      final res = await apiService.get('/gameweeks');
      if (mounted) {
        setState(() {
          _gameweeks  = res.data as List? ?? [];
          _loadingGws = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Erreur chargement des gameweeks'; _loadingGws = false; });
    }
  }

  Future<void> _loadPlayers() async {
    if (_selectedGw == null) return;
    setState(() { _loadingPlayers = true; _error = null; });
    try {
      final res = await apiService.get('/players?limit=200');
      final players = (res.data?['players'] as List? ?? []);

      // Fetch existing scores for this gameweek to prefill
      Response? scoresRes;
      try {
        scoresRes = await apiService.get('/gameweeks/${_selectedGw['id']}/scores');
      } catch (e) {
        debugPrint('[AdminStats._loadScoresPrefill] $e');
      }

      final scoreMap = <String, dynamic>{};
      if (scoresRes != null) {
        final scores = scoresRes.data?['playerScores'] as List? ?? [];
        for (final s in scores) {
          scoreMap[s['player_id'] as String? ?? ''] = s;
        }
      }

      for (final p in players) {
        final existing = scoreMap[p['id'] as String? ?? ''];
        p['_stats'] = {
          'goals':            existing?['goals']            ?? 0,
          'assists':          existing?['assists']          ?? 0,
          'minutes_played':   existing?['minutes_played']   ?? 0,
          'clean_sheet':      existing?['clean_sheet']      ?? false,
          'yellow_cards':     existing?['yellow_cards']     ?? 0,
          'red_cards':        existing?['red_cards']        ?? 0,
          'own_goals':        existing?['own_goals']        ?? 0,
          'penalties_saved':  existing?['penalties_saved']  ?? 0,
          'penalties_missed': existing?['penalties_missed'] ?? 0,
          'bonus':            existing?['bonus']            ?? 0,
        };
      }

      if (mounted) setState(() { _players = players; _loadingPlayers = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erreur chargement des joueurs'; _loadingPlayers = false; });
    }
  }

  Future<void> _gwAction(String action) async {
    if (_selectedGw == null) return;
    final gwId = _selectedGw['id'] as String;
    final gwNum = _selectedGw['number'];
    try {
      String msg;
      switch (action) {
        case 'start':
          await apiService.startGameweek(gwId);
          msg = 'GW$gwNum démarrée ✅';
          break;
        case 'finish':
          await apiService.finishGameweek(gwId);
          msg = 'GW$gwNum terminée ✅';
          break;
        case 'battles':
          await apiService.generateBattles(gwId, '');
          msg = 'Battles générées pour GW$gwNum ✅';
          break;
        case 'reload':
          await _loadPlayers();
          return;
        default:
          return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating),
        );
        await _loadGameweeks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _saveStats(dynamic player) async {
    final stats = player['_stats'] as Map<String, dynamic>;
    try {
      await apiService.post(
        '/gameweeks/${_selectedGw['id']}/scores',
        {'playerId': player['id'], ...stats},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stats de ${player['name']} sauvegardées'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] as String? ?? 'Erreur sauvegarde';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(
        title: const Text('Admin — Stats Joueurs', style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: const BackButton(color: Colors.white70),
        actions: [
          if (_selectedGw != null) ...[
            // Start / Finish / Battles selon le statut du GW
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: AppColors.surface,
              onSelected: _gwAction,
              itemBuilder: (_) {
                final status = _selectedGw['status'] as String? ?? '';
                return [
                  if (status == 'upcoming')
                    const PopupMenuItem(value: 'start', child: Row(children: [
                      Icon(Icons.play_arrow, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Démarrer le GW', style: TextStyle(color: Colors.white)),
                    ])),
                  if (status == 'active')
                    const PopupMenuItem(value: 'finish', child: Row(children: [
                      Icon(Icons.stop_circle_outlined, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text('Terminer le GW', style: TextStyle(color: Colors.white)),
                    ])),
                  if (status == 'active' || status == 'finished')
                    const PopupMenuItem(value: 'battles', child: Row(children: [
                      Icon(Icons.sports_kabaddi, color: AppColors.gold, size: 18),
                      SizedBox(width: 8),
                      Text('Générer Battles', style: TextStyle(color: Colors.white)),
                    ])),
                  const PopupMenuItem(value: 'reload', child: Row(children: [
                    Icon(Icons.refresh, color: AppColors.warning, size: 18),
                    SizedBox(width: 8),
                    Text('Recharger joueurs', style: TextStyle(color: Colors.white)),
                  ])),
                ];
              },
            ),
          ],
        ],
      ),
      body: _loadingGws
          ? const Center(child: CircularProgressIndicator(color: AppColors.warning))
          : Column(
              children: [
                _GameweekSelector(
                  gameweeks: _gameweeks,
                  selected: _selectedGw,
                  onSelected: (gw) {
                    setState(() { _selectedGw = gw; _players = []; });
                    _loadPlayers();
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_loadingPlayers)
                  const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.warning)))
                else if (_players.isEmpty && _selectedGw != null)
                  const Expanded(
                    child: Center(
                      child: Text('Aucun joueur trouvé', style: TextStyle(color: Colors.white54)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _players.length,
                      itemBuilder: (context, i) => _PlayerStatCard(
                        player: _players[i],
                        onSave: () => _saveStats(_players[i]),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GameweekSelector extends StatelessWidget {
  final List<dynamic> gameweeks;
  final dynamic selected;
  final ValueChanged<dynamic> onSelected;

  const _GameweekSelector({required this.gameweeks, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.background,
      child: Row(
        children: [
          const Text('Gameweek :', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<dynamic>(
              initialValue: selected,
              dropdownColor: AppColors.background,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('Choisir…', style: TextStyle(color: Colors.white54)),
              items: gameweeks.map((gw) {
                final status = gw['status'] as String? ?? '';
                final statusColor = status == 'active' ? Colors.green
                    : status == 'finished' ? Colors.grey
                    : AppColors.warning;
                return DropdownMenuItem(
                  value: gw,
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('GW ${gw['number']} — $status',
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (gw) { if (gw != null) onSelected(gw); },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerStatCard extends StatefulWidget {
  final dynamic player;
  final VoidCallback onSave;

  const _PlayerStatCard({required this.player, required this.onSave});

  @override
  State<_PlayerStatCard> createState() => _PlayerStatCardState();
}

class _PlayerStatCardState extends State<_PlayerStatCard> {
  bool _expanded = false;

  Map<String, dynamic> get stats => widget.player['_stats'] as Map<String, dynamic>;

  void _update(String key, dynamic value) {
    setState(() => stats[key] = value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  PlayerAvatar(
                    name: widget.player['name'] as String? ?? '',
                    nationality: widget.player['nationality'] as String?,
                    radius: 19,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.player['name'] as String? ?? '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '${widget.player['position'] ?? ''} · ${widget.player['club'] ?? ''}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Quick stats summary
                  _StatBadge(label: 'G', value: stats['goals'] ?? 0, color: AppColors.success),
                  const SizedBox(width: 6),
                  _StatBadge(label: 'A', value: stats['assists'] ?? 0, color: AppColors.info),
                  const SizedBox(width: 6),
                  _StatBadge(label: 'Min', value: stats['minutes_played'] ?? 0, color: const Color(0xFF8b5cf6)),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expanded stats form
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.surface),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _NumberField(label: 'Buts', value: stats['goals'], onChanged: (v) => _update('goals', v))),
                      const SizedBox(width: 12),
                      Expanded(child: _NumberField(label: 'Passes D.', value: stats['assists'], onChanged: (v) => _update('assists', v))),
                      const SizedBox(width: 12),
                      Expanded(child: _NumberField(label: 'Minutes', value: stats['minutes_played'], onChanged: (v) => _update('minutes_played', v))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _NumberField(label: 'Cartons J', value: stats['yellow_cards'], onChanged: (v) => _update('yellow_cards', v))),
                      const SizedBox(width: 12),
                      Expanded(child: _NumberField(label: 'Carton R', value: stats['red_cards'], onChanged: (v) => _update('red_cards', v))),
                      const SizedBox(width: 12),
                      Expanded(child: _NumberField(label: 'CSC', value: stats['own_goals'], onChanged: (v) => _update('own_goals', v))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _NumberField(label: 'Pen. arrêtés', value: stats['penalties_saved'], onChanged: (v) => _update('penalties_saved', v))),
                      const SizedBox(width: 12),
                      Expanded(child: _NumberField(label: 'Pen. ratés', value: stats['penalties_missed'], onChanged: (v) => _update('penalties_missed', v))),
                      const SizedBox(width: 12),
                      Expanded(child: _NumberField(label: 'Bonus', value: stats['bonus'], onChanged: (v) => _update('bonus', v))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Clean sheet toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Clean Sheet', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      value: stats['clean_sheet'] as bool? ?? false,
                      onChanged: (v) => _update('clean_sheet', v),
                      activeThumbColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: widget.onSave,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Sauvegarder', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumberField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.warning, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }
}
