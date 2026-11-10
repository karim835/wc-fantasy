import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// A persistent banner shown at the top of the screen when offline.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _online = connectivityService.isOnline;
    connectivityService.addListener(_onConnectivityChange);
  }

  @override
  void dispose() {
    connectivityService.removeListener(_onConnectivityChange);
    super.dispose();
  }

  void _onConnectivityChange() {
    if (mounted) setState(() => _online = connectivityService.isOnline);
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        color: Colors.red.shade800,
        child: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mode hors ligne — données en cache',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
