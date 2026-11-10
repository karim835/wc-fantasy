import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../models/league.dart';

class LeagueCard extends StatelessWidget {
  final League league;
  final VoidCallback? onTap;
  final VoidCallback? onLeaderboard;

  const LeagueCard({
    super.key,
    required this.league,
    this.onTap,
    this.onLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: league.isActive
              ? AppColors.gold.withValues(alpha: 0.35)
              : AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                    child: Text(
                      league.initials,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + season
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          league.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (league.season != null)
                          Text(
                            'Season ${league.season}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                      ],
                    ),
                  ),

                  // Privacy icon
                  Icon(
                    league.isPrivate ? Icons.lock : Icons.lock_open,
                    color: Colors.white38,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.people,
                    label: '${league.memberCount}/${league.maxMembers}',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.star,
                    label: '${league.myPoints} pts',
                    color: AppColors.gold,
                  ),
                  const Spacer(),
                  if (onLeaderboard != null)
                    TextButton.icon(
                      onPressed: onLeaderboard,
                      icon: const Icon(Icons.emoji_events, size: 16),
                      label: const Text('Classement', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),

              // Invite code (only for private leagues owned by user)
              if (league.isPrivate && league.inviteCode != null) ...[
                const Divider(color: Colors.white12),
                Row(
                  children: [
                    const Text('Code: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      league.inviteCode!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // Copy to clipboard
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copié !'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy, size: 14, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = Colors.white54,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
