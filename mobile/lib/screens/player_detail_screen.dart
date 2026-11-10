import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../models/player.dart';
import '../services/player_image_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/player_photo.dart';

class PlayerDetailScreen extends StatefulWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  PlayerInfo? _info; // online bio fallback when the DB lacks age/height/weight

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    if (p.dateOfBirth == null || p.heightCm == null || p.weightKg == null) {
      PlayerImageService.getInfo(p.name).then((info) {
        if (mounted && info != null) setState(() => _info = info);
      });
    }
  }

  static int? _ageFrom(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) a--;
    return a;
  }

  @override
  Widget build(BuildContext context) {
    final player      = widget.player;
    final name        = player.name;
    final position    = player.position;
    final club        = player.club ?? '-';
    final nationality = player.nationality ?? '-';
    final price       = player.price;
    final points      = player.points;
    final form        = player.form;
    final injury      = player.injuryStatus;
    final stats       = player.stats;
    final posColor    = _posColor(position);

    // Effective bio: DB value first, then online fallback.
    final age      = _ageFrom(player.dateOfBirth ?? _info?.dateOfBirth);
    final heightCm = player.heightCm ?? _info?.heightCm;
    final weightKg = player.weightKg ?? _info?.weightKg;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background with position color
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          posColor.withValues(alpha: 0.8),
                          AppColors.surface,
                        ],
                      ),
                    ),
                  ),
                  // Player photo centered
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: PlayerPhotoLarge(name: name, photoUrl: player.photoUrl ?? _info?.photoUrl, nationality: nationality, height: 180),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Player Info Header ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  color: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _PosBadge(position: position, color: posColor),
                                    const SizedBox(width: 8),
                                    Text('${flagEmoji(nationality)}  $nationality',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.sports_soccer, color: Colors.white38, size: 14),
                                    const SizedBox(width: 4),
                                    Text(club, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Price badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                Text('\$${price.toStringAsFixed(1)}M',
                                    style: const TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const Text('Prix', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Injury badge
                      if (injury != null && injury.toLowerCase() != 'fit') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.medical_services, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 6),
                              Text('Blessé: $injury',
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Performance Cards ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _InfoCard(
                        label: 'Points Fantasy',
                        value: '$points',
                        icon: Icons.star_rounded,
                        color: const Color(0xFFFFA726),
                      ),
                      const SizedBox(width: 10),
                      _InfoCard(
                        label: 'Forme actuelle',
                        value: form.toStringAsFixed(1),
                        icon: Icons.trending_up,
                        color: _formColor(form),
                      ),
                      const SizedBox(width: 10),
                      _InfoCard(
                        label: 'Position',
                        value: position,
                        icon: Icons.place,
                        color: posColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Infos personnelles ─────────────────────────────────────
                _Section(
                  title: 'Informations',
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.flag, label: 'Nationalité', value: '${ flagEmoji(nationality)} $nationality'),
                      _InfoRow(icon: Icons.sports_soccer, label: 'Club', value: club),
                      _InfoRow(icon: Icons.cake_outlined, label: 'Âge', value: age != null ? '$age ans' : '—'),
                      _InfoRow(icon: Icons.height, label: 'Taille', value: heightCm != null ? '$heightCm cm' : '—'),
                      _InfoRow(icon: Icons.monitor_weight_outlined, label: 'Poids', value: weightKg != null ? '$weightKg kg' : '—'),
                      _InfoRow(icon: Icons.category, label: 'Poste', value: _positionFull(position)),
                      _InfoRow(icon: Icons.attach_money, label: 'Valeur marchande', value: '\$${price.toStringAsFixed(1)}M'),
                      _InfoRow(
                        icon: Icons.health_and_safety,
                        label: 'Condition physique',
                        value: injury == null || injury.toLowerCase() == 'fit' ? 'Fit ✅' : injury,
                        valueColor: injury == null || injury.toLowerCase() == 'fit' ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Statistiques ──────────────────────────────────────────
                if (stats.isNotEmpty)
                  _Section(
                    title: 'Statistiques',
                    child: Column(
                      children: stats.entries.map((e) =>
                          _InfoRow(
                            icon: _statIcon(e.key),
                            label: _statLabel(e.key),
                            value: '${e.value}',
                          )).toList(),
                    ),
                  )
                else
                  _Section(
                    title: 'Statistiques',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Les statistiques seront disponibles\npendant la Coupe du Monde 2026',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK':  return AppColors.goldBright;
      case 'DEF': return AppColors.gold;
      case 'MID': return const Color(0xFF66BB6A);
      case 'FWD': return const Color(0xFFEF5350);
      default:    return Colors.white54;
    }
  }

  String _positionFull(String pos) {
    switch (pos) {
      case 'GK':  return 'Gardien de but';
      case 'DEF': return 'Défenseur';
      case 'MID': return 'Milieu de terrain';
      case 'FWD': return 'Attaquant';
      default:    return pos;
    }
  }

  Color _formColor(double form) {
    if (form >= 8) return const Color(0xFF66BB6A);
    if (form >= 6) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  String _statLabel(String key) {
    const labels = <String, String>{
      'goals': 'Buts', 'assists': 'Passes décisives',
      'clean_sheets': 'Clean sheets', 'yellow_cards': 'Cartons jaunes',
      'red_cards': 'Cartons rouges', 'minutes_played': 'Minutes jouées',
      'saves': 'Arrêts', 'matches': 'Matchs joués',
      'penalties_saved': 'Penaltys arrêtés', 'penalties_missed': 'Penaltys manqués',
      'own_goals': 'Buts contre son camp',
    };
    return labels[key] ?? key;
  }

  IconData _statIcon(String key) {
    switch (key) {
      case 'goals': return Icons.sports_soccer;
      case 'assists': return Icons.assistant;
      case 'clean_sheets': return Icons.shield;
      case 'yellow_cards': return Icons.square;
      case 'red_cards': return Icons.square;
      case 'saves': return Icons.pan_tool;
      case 'minutes_played': return Icons.timer;
      default: return Icons.bar_chart;
    }
  }
}

// ── Widgets helpers ────────────────────────────────────────────────────────────

class _PosBadge extends StatelessWidget {
  final String position;
  final Color color;
  const _PosBadge({required this.position, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(position, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _InfoCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13))),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
