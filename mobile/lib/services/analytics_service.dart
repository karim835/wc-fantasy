import 'dart:async';
import 'cache_service.dart';

enum AnalyticsEvent {
  screenView,
  login,
  logout,
  draftPlayer,
  createLeague,
  joinLeague,
  completePrediction,
  completeChallenge,
  viewBattle,
  makeTransfer,
  viewProfile,
  changeSettings,
}

class AnalyticsService {
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;

  void init() {
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  void dispose() {
    _flushTimer?.cancel();
    _flush();
  }

  void logScreen(String screenName) {
    _log(AnalyticsEvent.screenView, {'screen': screenName});
  }

  void logEvent(AnalyticsEvent event, [Map<String, dynamic>? params]) {
    _log(event, params ?? {});
  }

  void _log(AnalyticsEvent event, Map<String, dynamic> params) {
    _buffer.add({
      'event': event.name,
      'params': params,
      'ts': DateTime.now().toIso8601String(),
    });
    if (_buffer.length >= 20) _flush();
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final events = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    try {
      final existing = await cacheService.getPersistent('analytics:log') as List? ?? [];
      final merged = [...existing, ...events];
      // Keep only last 500 events
      final trimmed = merged.length > 500 ? merged.sublist(merged.length - 500) : merged;
      await cacheService.setPersistent('analytics:log', trimmed);
    } catch (_) {}
  }

  Future<Map<String, int>> getEventCounts() async {
    final events = await cacheService.getPersistent('analytics:log') as List? ?? [];
    final counts = <String, int>{};
    for (final e in events.cast<Map>()) {
      final key = e['event'] as String? ?? 'unknown';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> clearLog() async {
    _buffer.clear();
    await cacheService.setPersistent('analytics:log', []);
  }
}

final analyticsService = AnalyticsService();
