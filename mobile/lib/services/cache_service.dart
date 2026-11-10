import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight offline cache using shared_preferences.
/// Stores JSON-encoded data with an optional TTL (seconds).
class CacheService {
  static const int _defaultTtl = 300; // 5 minutes

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Store any JSON-serialisable value.
  Future<void> set(String key, dynamic value, {int ttl = _defaultTtl}) async {
    final prefs = await _prefs;
    final payload = jsonEncode({
      'data': value,
      'expires': DateTime.now().add(Duration(seconds: ttl)).millisecondsSinceEpoch,
    });
    await prefs.setString(key, payload);
  }

  /// Retrieve a cached value. Returns null if missing or expired.
  Future<dynamic> get(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expires = map['expires'] as int;
      if (DateTime.now().millisecondsSinceEpoch > expires) {
        await prefs.remove(key);
        return null;
      }
      return map['data'];
    } catch (_) {
      return null;
    }
  }

  /// Store without expiry (persistent until explicitly cleared).
  Future<void> setPersistent(String key, dynamic value) async {
    final prefs = await _prefs;
    await prefs.setString('p:$key', jsonEncode(value));
  }

  Future<dynamic> getPersistent(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString('p:$key');
    if (raw == null) return null;
    try { return jsonDecode(raw); } catch (_) { return null; }
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
    await prefs.remove('p:$key');
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}

final cacheService = CacheService();
