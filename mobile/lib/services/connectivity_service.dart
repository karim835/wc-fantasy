import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports real network connectivity via `connectivity_plus` (works on Android,
/// iOS, desktop AND web). Considered online unless the platform explicitly
/// reports no network — so the offline banner no longer false-triggers from a
/// flaky DNS lookup the way the old `dart:io` ping did.
class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _isOnline;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    final conn = Connectivity();
    try {
      _apply(await conn.checkConnectivity());
    } catch (_) {
      _isOnline = true; // assume online if the platform check is unavailable
    }
    _sub = conn.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    // Offline only when the sole result is "none"; empty/unknown → assume online.
    final online = !(results.length == 1 && results.first == ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final connectivityService = ConnectivityService();
