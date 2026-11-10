import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Country flag emojis by nationality/country name.
const _flags = <String, String>{
  'France': '🇫🇷', 'Brazil': '🇧🇷', 'Argentina': '🇦🇷', 'Germany': '🇩🇪',
  'Spain': '🇪🇸', 'England': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'Portugal': '🇵🇹', 'Netherlands': '🇳🇱',
  'Belgium': '🇧🇪', 'Italy': '🇮🇹', 'Croatia': '🇭🇷', 'Morocco': '🇲🇦',
  'Senegal': '🇸🇳', 'Japan': '🇯🇵', 'South Korea': '🇰🇷', 'Australia': '🇦🇺',
  'USA': '🇺🇸', 'Mexico': '🇲🇽', 'Canada': '🇨🇦', 'Ecuador': '🇪🇨',
  'Uruguay': '🇺🇾', 'Colombia': '🇨🇴', 'Chile': '🇨🇱', 'Peru': '🇵🇪',
  'Cameroon': '🇨🇲', 'Ghana': '🇬🇭', 'Nigeria': '🇳🇬', 'Egypt': '🇪🇬',
  'Tunisia': '🇹🇳', 'Algeria': '🇩🇿', 'Iran': '🇮🇷', 'Saudi Arabia': '🇸🇦',
  'Qatar': '🇶🇦', 'Poland': '🇵🇱', 'Denmark': '🇩🇰', 'Switzerland': '🇨🇭',
  'Serbia': '🇷🇸', 'Wales': '🏴󠁧󠁢󠁷󠁬󠁳󠁿', 'Costa Rica': '🇨🇷', 'Ivory Coast': '🇨🇮',
  'South Africa': '🇿🇦', 'Turkey': '🇹🇷', 'Ukraine': '🇺🇦', 'Greece': '🇬🇷',
  'Czech Republic': '🇨🇿', 'Austria': '🇦🇹', 'Sweden': '🇸🇪', 'Norway': '🇳🇴',
  // WC 2026 squads present in the DB seed
  'Cape Verde': '🇨🇻', 'DR Congo': '🇨🇩', 'Uzbekistan': '🇺🇿', 'Jordan': '🇯🇴',
  'Haiti': '🇭🇹', 'Curaçao': '🇨🇼', 'Scotland': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'Panama': '🇵🇦',
  'New Zealand': '🇳🇿', 'Paraguay': '🇵🇾', 'United States': '🇺🇸',
};

String flagEmoji(String? nationality) => _flags[nationality ?? ''] ?? '🌍';

/// Gradient colors from a string (name → unique gradient).
List<Color> _avatarGradient(String name) {
  final gradients = [
    [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
    [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)],
    [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
    [const Color(0xFFC62828), const Color(0xFFEF5350)],
    [const Color(0xFF00838F), const Color(0xFF26C6DA)],
    [const Color(0xFFEF6C00), const Color(0xFFFFA726)],
    [const Color(0xFF4527A0), const Color(0xFF7E57C2)],
    [const Color(0xFF00695C), const Color(0xFF26A69A)],
    [const Color(0xFF283593), const Color(0xFF5C6BC0)],
    [const Color(0xFF880E4F), const Color(0xFFEC407A)],
  ];
  final hash = name.codeUnits.fold(0, (a, b) => a + b);
  return gradients[hash % gradients.length];
}

/// Circular avatar for a player: shows network image if available,
/// otherwise initials on a colored background with optional flag.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? nationality;
  final double radius;
  final bool showFlag;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.nationality,
    this.radius = 22,
    this.showFlag = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final gradient = _avatarGradient(name);

    Widget avatar;

    if (imageUrl != null && imageUrl!.isNotEmpty && !imageUrl!.contains('ui-avatars.com')) {
      // Real external image (not generated)
      avatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _gradientAvatar(initials, gradient, radius),
          placeholder: (_, __) => _gradientAvatar(initials, gradient, radius),
        ),
      );
    } else {
      // Beautiful gradient avatar with initials
      avatar = _gradientAvatar(initials, gradient, radius);
    }

    if (!showFlag || nationality == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: -2, right: -4,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Text(flagEmoji(nationality), style: TextStyle(fontSize: radius * 0.52)),
          ),
        ),
      ],
    );
  }

  Widget _gradientAvatar(String initials, List<Color> gradient, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.65,
            letterSpacing: 1,
            shadows: const [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
          ),
        ),
      ),
    );
  }

  String _initials(String n) {
    final parts = n.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }
}
