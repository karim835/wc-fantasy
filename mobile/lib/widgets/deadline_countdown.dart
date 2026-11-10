import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Self-contained "transfers lock in Hh Mm Ss" pill. Fetches the current
/// gameweek once, then ticks every second until its deadline. Renders nothing
/// when there's no active/upcoming gameweek or no deadline set.
///
/// Drop it anywhere (Draft header, Home, Gameweeks) with no arguments.
class DeadlineCountdown extends StatefulWidget {
  /// Compact = a small inline pill (for app-bar-adjacent headers).
  final bool compact;
  const DeadlineCountdown({super.key, this.compact = false});

  @override
  State<DeadlineCountdown> createState() => _DeadlineCountdownState();
}

class _DeadlineCountdownState extends State<DeadlineCountdown> {
  Timer? _timer;
  DateTime? _deadline;
  int? _gwNumber;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    final gw = await apiService.getCurrentGameweek();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _gwNumber = (gw?['number'] as num?)?.toInt();
      final raw = gw?['deadline'];
      _deadline = raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _deadline == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    final remaining = _deadline!.difference(DateTime.now());
    final passed = remaining.isNegative;
    final urgent = !passed && remaining.inHours < 1;
    final accent = passed
        ? Colors.white38
        : urgent
            ? AppColors.red
            : AppColors.goldBright;

    final text = passed ? l.deadlinePassed : _format(remaining);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12, vertical: widget.compact ? 5 : 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(passed ? Icons.lock_outline : Icons.timer_outlined, size: widget.compact ? 14 : 16, color: accent),
          const SizedBox(width: 6),
          if (_gwNumber != null) ...[
            Text(
              l.gameweekShort(_gwNumber!),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: widget.compact ? 11 : 12),
            ),
            Text('  ·  ', style: TextStyle(color: Colors.white38, fontSize: widget.compact ? 11 : 12)),
          ],
          if (!widget.compact && !passed) ...[
            Text('${l.deadlineLabel}  ', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: widget.compact ? 12 : 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (days > 0) return '${days}j ${two(h)}:${two(m)}:${two(s)}';
    return '${two(h)}:${two(m)}:${two(s)}';
  }
}
