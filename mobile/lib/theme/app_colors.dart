import 'package:flutter/material.dart';

/// Central brand + semantic color tokens for WC Fantasy.
///
/// Single source of truth — never hardcode `Color(0x..)` in screens/widgets.
/// Brand palette: Gold (primary), Red (live/alert), Navy (surfaces).
class AppColors {
  AppColors._();

  // ─── Brand ───────────────────────────────────────────────────────────────
  /// Primary brand accent — buttons, highlights, selected states.
  static const Color gold = Color(0xFFC8961C);

  /// Brighter gold for accent text / icons on dark surfaces (better contrast).
  static const Color goldBright = Color(0xFFE2A92B);

  /// Secondary pop — live indicators, alerts, destructive actions.
  static const Color red = Color(0xFFC41E3A);

  /// Core navy — cards & surfaces.
  static const Color navy = Color(0xFF1F3864);

  // ─── Canvas / surfaces ─────────────────────────────────────────────────────
  /// App scaffold background — deep navy, near-black for premium contrast.
  static const Color background = Color(0xFF0E1A2C);

  /// Default card / surface.
  static const Color surface = navy;

  /// Elevated surface (modals, raised cards, selected rows).
  static const Color surfaceElevated = Color(0xFF274879);

  /// Hairline borders / dividers on dark.
  static const Color border = Color(0x1FFFFFFF); // white @ 12%

  // ─── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFAEB9C9);
  static const Color textHint = Color(0xFF6E7E92);

  /// Text/icon color that sits on top of [gold].
  static const Color onGold = Color(0xFF0E1A2C);

  // ─── Semantic ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2EA86A);
  static const Color warning = Color(0xFFE0A82E);
  static const Color info = Color(0xFF3D7BE0);

  // ─── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, surfaceElevated],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldBright, gold],
  );

  /// Signature red→navy header gradient — used on app bars / hero areas
  /// to give the whole app one cohesive identity.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [red, navy],
  );

  /// Subtle red-tinted navy gradient for list/content cards.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, Color(0xFF3A2740)],
  );

  /// Hairline red border/glow for cards.
  static final Color cardBorder = red.withValues(alpha: 0.18);

  // ─── Position colors (GK / DEF / MID / FWD) ────────────────────────────────
  static Color position(String? pos) {
    switch ((pos ?? '').toUpperCase()) {
      case 'GK':
        return warning; // amber-gold
      case 'DEF':
        return info; // blue
      case 'MID':
        return success; // green
      case 'FWD':
        return red; // red
      default:
        return textSecondary;
    }
  }

  // ─── News category colors ────────────────────────────────────────────────────
  static Color category(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'match':
        return gold;
      case 'transfert':
      case 'transfer':
        return success;
      case 'blessure':
      case 'injury':
        return red;
      case 'équipe':
      case 'equipe':
      case 'team':
        return info;
      case 'qualif':
        return const Color(0xFF8B5CF6); // purple
      default:
        return textSecondary; // Actu / misc
    }
  }

  // ─── Rank medals (1 / 2 / 3) ──────────────────────────────────────────────────
  static const Color medalGold = Color(0xFFF4C430);
  static const Color medalSilver = Color(0xFFC0C0C0);
  static const Color medalBronze = Color(0xFFCD7F32);

  static Color? medal(int rank) {
    switch (rank) {
      case 1:
        return medalGold;
      case 2:
        return medalSilver;
      case 3:
        return medalBronze;
      default:
        return null;
    }
  }

  // ─── Form rating color (0–10) ────────────────────────────────────────────────
  static Color form(num value) {
    if (value >= 8) return success;
    if (value >= 6.5) return goldBright;
    if (value >= 5) return warning;
    return red;
  }
}
