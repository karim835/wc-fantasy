import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/haptics.dart';
import 'player_photo.dart';

/// Horizontal bar of the three WC chips above the pitch. Reflects used / armed /
/// available state from the team and arms a chip via [ApiService.armChip].
class ChipsBar extends StatelessWidget {
  final Map<String, dynamic> team;
  final String leagueId;
  final VoidCallback onChanged;

  const ChipsBar({super.key, required this.team, required this.leagueId, required this.onChanged});

  List<Map<String, dynamic>> get _players =>
      ((team['players'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  Set<String> get _usedChips {
    final used = (team['chips_used'] as List?) ?? const [];
    return used.map((e) => (e as Map)['chip'].toString()).toSet();
  }

  String? get _activeChip => team['active_chip']?.toString();

  Future<void> _arm(BuildContext context, _ChipDef def) async {
    final l = AppLocalizations.of(context);
    Haptics.light();

    String? boostId;
    if (def.key == 'super_sub') {
      boostId = await _pickBoostPlayer(context);
      if (boostId == null) return; // cancelled
    } else {
      final ok = await _confirm(context, def);
      if (ok != true) return;
    }

    try {
      await apiService.armChip(leagueId, def.key, boostPlayerId: boostId);
      Haptics.success();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.chipArmedMsg(def.name(l))), backgroundColor: AppColors.success),
        );
      }
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.error}: ${e.toString().contains('400') ? l.chipUsed : ''}'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<bool?> _confirm(BuildContext context, _ChipDef def) {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(children: [Icon(def.icon, color: def.color), const SizedBox(width: 10), Text(def.name(l), style: const TextStyle(color: Colors.white, fontSize: 18))]),
        content: Text(def.desc(l), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: def.color, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.chipArm),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickBoostPlayer(BuildContext context) {
    final l = AppLocalizations.of(context);
    final players = _players;
    if (players.isEmpty) return Future.value(null);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(l.chooseBoostPlayer, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: players.map((p) => ListTile(
                      leading: PlayerPhoto(name: p['name'] as String? ?? '', photoUrl: p['photo_url'] as String?, radius: 18),
                      title: Text(p['name'] as String? ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${p['position'] ?? ''}', style: const TextStyle(color: Colors.white54)),
                      onTap: () => Navigator.of(ctx).pop(p['id'].toString()),
                    )).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final used = _usedChips;
    final active = _activeChip;

    final defs = <_ChipDef>[
      _ChipDef('triple_captain', Icons.local_fire_department, AppColors.red, (x) => x.chipTripleCaptain, (x) => x.chipTripleCaptainDesc),
      _ChipDef('super_sub', Icons.change_circle_outlined, AppColors.info, (x) => x.chipSuperSub, (x) => x.chipSuperSubDesc),
      _ChipDef('shield', Icons.shield_outlined, const Color(0xFF22C55E), (x) => x.chipShield, (x) => x.chipShieldDesc),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: AppColors.background,
      child: Row(
        children: defs.map((d) {
          final isUsed = used.contains(d.key);
          final isArmed = active == d.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ChipCard(
                def: d,
                status: isUsed ? l.chipUsed : isArmed ? l.chipArmed : l.chipAvailable,
                state: isUsed ? _ChipState.used : isArmed ? _ChipState.armed : _ChipState.available,
                onTap: (isUsed || isArmed) ? null : () => _arm(context, d),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _ChipState { available, armed, used }

class _ChipDef {
  final String key;
  final IconData icon;
  final Color color;
  final String Function(AppLocalizations) name;
  final String Function(AppLocalizations) desc;
  const _ChipDef(this.key, this.icon, this.color, this.name, this.desc);
}

class _ChipCard extends StatelessWidget {
  final _ChipDef def;
  final String status;
  final _ChipState state;
  final VoidCallback? onTap;
  const _ChipCard({required this.def, required this.status, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dim = state == _ChipState.used;
    final armed = state == _ChipState.armed;
    return Material(
      color: armed ? def.color.withValues(alpha: 0.18) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: armed ? def.color : AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Icon(def.icon, color: dim ? Colors.white24 : def.color, size: 22),
              const SizedBox(height: 4),
              Text(
                def.name(l),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: dim ? Colors.white38 : Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                status,
                style: TextStyle(color: dim ? Colors.white24 : (armed ? def.color : Colors.white54), fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
