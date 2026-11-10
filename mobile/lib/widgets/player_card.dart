import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../models/player.dart';

class PlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;
  final VoidCallback? onRiskCheck;
  final bool isInTeam;
  final bool compact;

  const PlayerCard({
    super.key,
    required this.player,
    this.onPick,
    this.onRemove,
    this.onRiskCheck,
    this.isInTeam = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: compact ? _buildCompact() : _buildFull(context),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Position badge
          _PositionBadge(position: player.position),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (player.isInjured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          '⚠️ Injury',
                          style: TextStyle(color: Colors.red, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.club ?? ''} • ${player.nationality ?? ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatChip(label: 'Form', value: player.form.toStringAsFixed(1), color: _formColor(player.form)),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Pts', value: '${player.points}', color: AppColors.gold),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Price + actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                player.priceLabel,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRiskCheck != null)
                    IconButton(
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      color: Colors.orange,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: onRiskCheck,
                      tooltip: 'Risk analysis',
                    ),
                  const SizedBox(width: 8),
                  if (onPick != null && !isInTeam)
                    IconButton(
                      icon: const Icon(Icons.add_circle, size: 22),
                      color: const Color(0xFF66BB6A),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: onPick,
                      tooltip: 'Pick player',
                    ),
                  if (onRemove != null && isInTeam)
                    IconButton(
                      icon: const Icon(Icons.remove_circle, size: 22),
                      color: Colors.red,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: onRemove,
                      tooltip: 'Remove player',
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return ListTile(
      dense: true,
      leading: _PositionBadge(position: player.position, size: 32),
      title: Text(player.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: Text(player.club ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
      trailing: Text(player.priceLabel, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
    );
  }

  Color _formColor(double form) {
    if (form >= 7) return const Color(0xFF66BB6A);
    if (form >= 5) return Colors.orange;
    return Colors.red;
  }
}

class _PositionBadge extends StatelessWidget {
  final String position;
  final double size;

  const _PositionBadge({required this.position, this.size = 40});

  Color get _color {
    switch (position) {
      case 'GK':  return AppColors.goldBright;
      case 'DEF': return AppColors.gold;
      case 'MID': return const Color(0xFF66BB6A);
      case 'FWD': return const Color(0xFFEF5350);
      default:    return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.6)),
      ),
      child: Center(
        child: Text(
          position,
          style: TextStyle(
            color: _color,
            fontSize: size * 0.28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
