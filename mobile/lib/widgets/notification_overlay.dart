import 'dart:async';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Wraps the entire app and shows toast-style in-app notifications
/// driven by [NotificationService].
class NotificationOverlay extends StatefulWidget {
  final Widget child;
  const NotificationOverlay({super.key, required this.child});

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with SingleTickerProviderStateMixin {
  AppNotification? _current;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  StreamSubscription<AppNotification>? _sub;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _sub = notificationService.stream.listen(_show);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _show(AppNotification notification) {
    _hideTimer?.cancel();
    setState(() => _current = notification);
    _animCtrl.forward(from: 0);
    _hideTimer = Timer(const Duration(seconds: 4), _hide);
  }

  void _hide() {
    _animCtrl.reverse().then((_) {
      if (mounted) setState(() => _current = null);
    });
  }

  Color _bgColor(NotificationType type) {
    switch (type) {
      case NotificationType.success: return const Color(0xFF2E7D32);
      case NotificationType.warning: return const Color(0xFFF57F17);
      case NotificationType.battle:  return const Color(0xFF1565C0);
      case NotificationType.gameweek: return const Color(0xFF4A148C);
      default: return AppColors.surface;
    }
  }

  IconData _icon(NotificationType type) {
    switch (type) {
      case NotificationType.success:  return Icons.check_circle;
      case NotificationType.warning:  return Icons.warning;
      case NotificationType.battle:   return Icons.sports_kabaddi;
      case NotificationType.gameweek: return Icons.calendar_today;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideAnim,
              child: GestureDetector(
                onTap: _hide,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _bgColor(_current!.type),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(_icon(_current!.type), color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_current!.title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(_current!.body,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const Icon(Icons.close, color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
