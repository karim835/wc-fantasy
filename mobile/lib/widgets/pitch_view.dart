import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/player.dart';
import '../screens/player_detail_screen.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/haptics.dart';
import 'chips_bar.dart';
import 'player_photo.dart';

/// FPL-style football-pitch team builder. Renders the 15-man squad as position
/// rows of slots on a green pitch; tapping an empty slot opens a position-filtered
/// player picker, tapping a filled slot offers captain / remove / profile actions.
///
/// Picks persist server-side immediately (via [ApiService]); [onChanged] asks the
/// parent to reload the team afterwards.
class PitchView extends StatefulWidget {
  final Map<String, dynamic> team;
  final String leagueId;
  final VoidCallback onChanged;

  const PitchView({
    super.key,
    required this.team,
    required this.leagueId,
    required this.onChanged,
  });

  /// Squad composition (matches backend POSITION_LIMITS): 2 GK, 5 DEF, 5 MID, 3 FWD.
  static const Map<String, int> squad = {'GK': 2, 'DEF': 5, 'MID': 5, 'FWD': 3};

  @override
  State<PitchView> createState() => _PitchViewState();
}

class _PitchViewState extends State<PitchView> {
  bool _busy = false;

  List<Map<String, dynamic>> get _players =>
      ((widget.team['players'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  double get _budget {
    final raw = widget.team['budget'];
    if (raw == null) return 100.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 100.0;
  }
  String? get _captainId => widget.team['captain_id']?.toString();

  List<Map<String, dynamic>> _playersFor(String pos) =>
      _players.where((p) => p['position'] == pos).toList();

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pick(String playerId) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await apiService.pickPlayer(widget.leagueId, playerId);
      Haptics.success();
      if (mounted) Navigator.of(context).pop(); // close picker sheet
      widget.onChanged();
    } catch (e) {
      final msg = e.toString();
      String userMsg = l.cannotAddPlayer;
      if (msg.contains('budget')) {
        userMsg = l.insufficientBudget;
      } else if (msg.contains('already')) {
        userMsg = l.playerAlreadyInTeam;
      } else if (msg.contains('full') || msg.contains('Max')) {
        userMsg = l.teamComplete;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMsg), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String playerId) async {
    setState(() => _busy = true);
    try {
      await apiService.removePlayer(widget.leagueId, playerId);
      Haptics.light();
      widget.onChanged();
    } catch (_) {/* keep silent — UI reloads on next change */} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCaptain(String playerId) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await apiService.setCaptain(widget.leagueId, playerId);
      Haptics.success();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.error}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Player picker (empty slot tapped) ────────────────────────────────────────

  Future<void> _openPicker(String pos) async {
    Haptics.light();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlayerPicker(
        position: pos,
        budget: _budget,
        excludeIds: _players.map((p) => p['id'].toString()).toSet(),
        onPick: _pick,
      ),
    );
  }

  // ─── Filled slot tapped → actions ─────────────────────────────────────────────

  Future<void> _openSlotActions(Map<String, dynamic> p) async {
    final l = AppLocalizations.of(context);
    final id = p['id'].toString();
    Haptics.light();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: PlayerPhoto(name: p['name'] as String? ?? '', photoUrl: p['photo_url'] as String?, nationality: p['nationality'] as String?, radius: 20),
              title: Text(p['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${p['position']} · ${p['club'] ?? ''}', style: const TextStyle(color: Colors.white54)),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.star, color: AppColors.goldBright),
              title: Text(l.makeCaptain, style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _setCaptain(id); },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.white70),
              title: Text(l.viewProfile, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayerDetailScreen(player: Player.fromJson(p)),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
              title: Text(l.removeFromTeam, style: const TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                final ok = await _confirm(l.removeFromTeam, l.removeConfirm(p['name'] as String? ?? ''));
                if (ok) _remove(id);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final l = AppLocalizations.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  // ─── Manage team (rename / formation / reset) ─────────────────────────────────

  Future<void> _openManageSheet() async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: widget.team['name'] as String? ?? '');
    String formation = widget.team['formation'] as String? ?? '4-3-3';
    const formations = ['4-3-3', '4-4-2', '3-5-2', '4-2-3-1', '5-3-2'];
    Haptics.light();

    await showModalBottomSheet(
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
              Text(l.manageTeam, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
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
                  labelStyle: TextStyle(color: formation == f ? AppColors.onGold : Colors.white70, fontWeight: FontWeight.bold),
                  backgroundColor: AppColors.background,
                )).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.onGold, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _saveTeamMeta(nameCtrl.text.trim(), formation);
                  },
                  child: Text(l.save, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  label: Text(l.resetSquad, style: const TextStyle(color: Colors.redAccent)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final ok = await _confirm(l.resetSquad, l.resetSquadConfirm);
                    if (ok) _resetSquad();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTeamMeta(String name, String formation) async {
    setState(() => _busy = true);
    try {
      await apiService.updateTeam(widget.leagueId, name: name.isEmpty ? null : name, formation: formation);
      Haptics.success();
      widget.onChanged();
    } catch (_) {/* reload reflects server state */} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetSquad() async {
    setState(() => _busy = true);
    try {
      await apiService.clearTeamPlayers(widget.leagueId);
      Haptics.success();
      widget.onChanged();
    } catch (_) {/* ignore */} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final count = _players.length;

    return Column(
      children: [
        _BudgetHeader(
          name: widget.team['name'] as String? ?? '',
          count: count,
          budget: _budget,
          formation: widget.team['formation'] as String? ?? '',
          onManage: _openManageSheet,
        ),
        ChipsBar(team: widget.team, leagueId: widget.leagueId, onChanged: widget.onChanged),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  // Render attacking-end first: FWD at the top, GK at the bottom,
                  // like a real pitch (squad map is GK→FWD, so reverse it).
                  children: PitchView.squad.entries.toList().reversed.map((e) {
                    return Expanded(child: _PositionRow(
                      position: e.key,
                      limit: e.value,
                      filled: _playersFor(e.key),
                      captainId: _captainId,
                      onEmptyTap: () => _openPicker(e.key),
                      onFilledTap: _openSlotActions,
                    ));
                  }).toList(),
                ),
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  ),
                ),
            ],
          ),
        ),
        _BottomBar(
          onAutoPick: _busy ? null : _autoPick,
          onSave: () {
            Haptics.success();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(count >= 15 ? l.teamComplete : '$count/15 · ${l.bank} ${_budget.toStringAsFixed(1)} M€'), backgroundColor: AppColors.success),
            );
          },
        ),
      ],
    );
  }

  Future<void> _autoPick() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    Haptics.light();
    setState(() => _busy = true);
    try {
      final res = await apiService.autoPick(widget.leagueId);
      final s = res['suggestion'] as Map<String, dynamic>?;
      if (!mounted) return;
      // Show the summary FIRST (popping via the dialog's own context), then
      // reload the squad AFTER it closes — reloading while the dialog is open
      // rebuilds this widget and invalidates the dialog's context (crash).
      await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l.autoPickLabel, style: const TextStyle(color: Colors.white)),
          content: Text(
            '${l.formation}: ${s?['formation'] ?? '—'}\n${l.expectedPoints}: ${s?['expected_points'] ?? '—'}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('OK'))],
        ),
      );
      widget.onChanged(); // reload the squad so the pitch fills with the picks
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🤖 ${l.error}'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ─── Budget header ──────────────────────────────────────────────────────────────

class _BudgetHeader extends StatelessWidget {
  final String name;
  final int count;
  final double budget;
  final String formation;
  final VoidCallback onManage;
  const _BudgetHeader({required this.name, required this.count, required this.budget, required this.formation, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Row(
        children: [
          _Badge(
            color: AppColors.red,
            label: '$count/15',
            sub: l.playersSelectedLabel,
          ),
          const SizedBox(width: 12),
          _Badge(
            color: AppColors.gold,
            label: '${budget.toStringAsFixed(1)} M€',
            sub: l.bank,
            onLight: true,
          ),
          const Spacer(),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                Text('${l.formation}: ${formation.isEmpty ? '4-3-3' : formation}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
            tooltip: l.manageTeam,
            onPressed: onManage,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final String label;
  final String sub;
  final bool onLight;
  const _Badge({required this.color, required this.label, required this.sub, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(color: onLight ? AppColors.onGold : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

// ─── Position row ───────────────────────────────────────────────────────────────

class _PositionRow extends StatelessWidget {
  final String position;
  final int limit;
  final List<Map<String, dynamic>> filled;
  final String? captainId;
  final VoidCallback onEmptyTap;
  final void Function(Map<String, dynamic>) onFilledTap;

  const _PositionRow({
    required this.position,
    required this.limit,
    required this.filled,
    required this.captainId,
    required this.onEmptyTap,
    required this.onFilledTap,
  });

  @override
  Widget build(BuildContext context) {
    final emptyCount = (limit - filled.length).clamp(0, limit);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ...filled.map((p) => _Slot.filled(
              player: p,
              isCaptain: captainId != null && captainId == p['id'].toString(),
              onTap: () => onFilledTap(p),
            )),
        ...List.generate(emptyCount, (_) => _Slot.empty(position: position, onTap: onEmptyTap)),
      ],
    );
  }
}

// ─── Slot (empty or filled) ─────────────────────────────────────────────────────

class _Slot extends StatelessWidget {
  final String position;
  final Map<String, dynamic>? player;
  final bool isCaptain;
  final VoidCallback onTap;

  const _Slot.empty({required this.position, required this.onTap})
      : player = null,
        isCaptain = false;

  const _Slot.filled({required Map<String, dynamic> this.player, required this.isCaptain, required this.onTap})
      : position = '';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: player == null ? _buildEmpty() : _buildFilled(),
    );
  }

  Widget _buildEmpty() {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(4)),
            child: Text(position, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilled() {
    final p = player!;
    final name = (p['name'] as String? ?? '').split(' ').last; // surname for compactness
    final rawPrice = p['price'];
    final price = rawPrice == null ? null : (rawPrice is num ? rawPrice.toDouble() : double.tryParse(rawPrice.toString()));
    return GestureDetector(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 62,
          child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerPhoto(
                name: p['name'] as String? ?? '',
                photoUrl: p['photo_url'] as String?,
                nationality: p['nationality'] as String?,
                radius: 21,
              ),
              if (isCaptain)
                Positioned(
                  right: -3, top: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: AppColors.goldBright, shape: BoxShape.circle),
                    child: const Text('C', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(4)),
            child: Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          if (price != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: const BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.vertical(bottom: Radius.circular(4))),
              child: Text('${price.toStringAsFixed(1)}M', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.onGold, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
        ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom bar ─────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback? onAutoPick;
  final VoidCallback onSave;
  const _BottomBar({required this.onAutoPick, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(l.pickStartingLineup, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          OutlinedButton.icon(
            onPressed: onAutoPick,
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: Text(l.autoPickLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(l.save, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─── Player picker sheet ──────────────────────────────────────────────────────────

class _PlayerPicker extends StatefulWidget {
  final String position;
  final double budget;
  final Set<String> excludeIds;
  final Future<void> Function(String playerId) onPick;

  const _PlayerPicker({
    required this.position,
    required this.budget,
    required this.excludeIds,
    required this.onPick,
  });

  @override
  State<_PlayerPicker> createState() => _PlayerPickerState();
}

class _PlayerPickerState extends State<_PlayerPicker> {
  List<Player> _players = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await apiService.getPlayers(position: widget.position, limit: 50);
      final raw = (res['players'] as List?) ?? const [];
      final list = raw
          .map((j) => Player.fromJson(j as Map<String, dynamic>))
          .where((p) => p.price <= widget.budget && !widget.excludeIds.contains(p.id))
          .toList()
        ..sort((a, b) => b.points.compareTo(a.points));
      if (mounted) setState(() { _players = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.position(widget.position).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.position, style: TextStyle(color: AppColors.position(widget.position), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(l.selectAPlayer, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${l.bank}: ${widget.budget.toStringAsFixed(1)} M€', style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _players.isEmpty
                    ? Center(child: Text(l.noAffordablePlayers, style: const TextStyle(color: Colors.white54)))
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _players.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final p = _players[i];
                          return _PickerTile(player: p, onPick: () => widget.onPick(p.id));
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final Player player;
  final VoidCallback onPick;
  const _PickerTile({required this.player, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          PlayerPhoto(name: player.name, photoUrl: player.photoUrl, nationality: player.nationality, showFlag: true, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text('${player.club ?? ''} · ${player.points} pts', style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${player.price.toStringAsFixed(1)}M', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pitch painter ──────────────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Grass gradient + mowing stripes.
    final grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E8A45), Color(0xFF0E5C2C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), grass);

    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.04);
    const bands = 6;
    final bandH = h / bands;
    for (var i = 0; i < bands; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * bandH, w, bandH), stripe);
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const m = 10.0; // margin
    final field = Rect.fromLTRB(m, m, w - m, h - m);
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(6)), line);

    // Halfway line + centre circle + spot.
    final midY = h / 2;
    canvas.drawLine(Offset(m, midY), Offset(w - m, midY), line);
    canvas.drawCircle(Offset(w / 2, midY), w * 0.13, line);
    canvas.drawCircle(Offset(w / 2, midY), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.4));

    // Penalty + goal boxes top & bottom.
    final boxW = w * 0.44, boxH = h * 0.16;
    final sixW = w * 0.22, sixH = h * 0.07;
    // top
    canvas.drawRect(Rect.fromLTWH((w - boxW) / 2, m, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH((w - sixW) / 2, m, sixW, sixH), line);
    // bottom
    canvas.drawRect(Rect.fromLTWH((w - boxW) / 2, h - m - boxH, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH((w - sixW) / 2, h - m - sixH, sixW, sixH), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
