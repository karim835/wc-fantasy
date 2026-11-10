import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] so tactile feedback is consistent and
/// easy to tune in one place. Use [selection] for taps that change selection
/// (nav, chips, tabs), [light] for button/card presses, [medium] for confirms.
class Haptics {
  Haptics._();

  static void selection() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.heavyImpact();
}
