import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:share_plus/share_plus.dart';

/// Widget de partage social — share_plus (100% GRATUIT)
///
/// Utilise le share sheet natif du système (Android Sharesheet / iOS Share Sheet)
/// Compatible : WhatsApp, Telegram, SMS, email, Instagram, Twitter, etc.
/// Aucune clé API, aucun compte, aucun coût.

class ShareButton extends StatelessWidget {
  final String text;
  final String tooltip;
  final IconData icon;
  final Color? color;

  const ShareButton({
    super.key,
    required this.text,
    this.tooltip = 'Partager',
    this.icon = Icons.share_outlined,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color ?? Colors.white70),
      tooltip: tooltip,
      onPressed: () => Share.share(text),
    );
  }
}

/// Bottom sheet de partage avec options stylées
class ShareSheet extends StatelessWidget {
  final String title;
  final String message;
  final String? score;
  final String? rank;
  final String? leagueName;

  const ShareSheet({
    super.key,
    required this.title,
    required this.message,
    this.score,
    this.rank,
    this.leagueName,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String? score,
    String? rank,
    String? leagueName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(
        title: title,
        message: message,
        score: score,
        rank: rank,
        leagueName: leagueName,
      ),
    );
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln('⚽ $title');
    buffer.writeln();
    buffer.writeln(message);
    if (score != null) buffer.writeln('🏆 Score: $score pts');
    if (rank != null)  buffer.writeln('📊 Classement: #$rank');
    if (leagueName != null) buffer.writeln('🎯 Ligue: $leagueName');
    buffer.writeln();
    buffer.writeln('#FantasyWC2026 #Qatar2026');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Partager',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Aperçu du message
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⚽', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'WC Fantasy',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
                if (score != null || rank != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (score != null) _StatBadge('🏆 $score pts', AppColors.warning),
                      if (score != null && rank != null) const SizedBox(width: 8),
                      if (rank != null) _StatBadge('#$rank', AppColors.gold),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bouton de partage
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Share.share(_buildShareText());
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Partager maintenant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Options rapides
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickShareOption(label: 'WhatsApp', icon: Icons.chat_outlined, color: const Color(0xFF25D366)),
              const SizedBox(width: 10),
              _QuickShareOption(label: 'Telegram', icon: Icons.send_outlined, color: const Color(0xFF2AABEE)),
              const SizedBox(width: 10),
              _QuickShareOption(label: 'SMS', icon: Icons.sms_outlined, color: const Color(0xFF8b5cf6)),
              const SizedBox(width: 10),
              _QuickShareOption(label: 'Plus...', icon: Icons.more_horiz, color: Colors.white38,
                onTap: () {
                  Navigator.pop(context);
                  Share.share(_buildShareText());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _QuickShareOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickShareOption({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap ?? () {
          Navigator.pop(context);
          Share.share('Partager via $label...');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
