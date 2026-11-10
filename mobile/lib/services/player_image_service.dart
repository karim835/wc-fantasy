import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight player info fetched online from TheSportsDB.
class PlayerInfo {
  final String? photoUrl;
  final DateTime? dateOfBirth;
  final int? heightCm;
  final int? weightKg;
  final String? position;
  final String? club;

  const PlayerInfo({
    this.photoUrl,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.position,
    this.club,
  });

  Map<String, dynamic> toCache() => {
        'p': photoUrl,
        'd': dateOfBirth?.toIso8601String(),
        'h': heightCm,
        'w': weightKg,
        'pos': position,
        'c': club,
      };

  factory PlayerInfo.fromCache(Map<String, dynamic> j) => PlayerInfo(
        photoUrl: j['p'] as String?,
        dateOfBirth: j['d'] != null ? DateTime.tryParse(j['d'] as String) : null,
        heightCm: j['h'] as int?,
        weightKg: j['w'] as int?,
        position: j['pos'] as String?,
        club: j['c'] as String?,
      );
}

/// Fetches player photos + bio from TheSportsDB (free, no API key needed).
/// Results are cached in SharedPreferences.
class PlayerImageService {
  static final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
  static const _prefix = 'pimg_';
  static const _infoPrefix = 'pinfo_';
  static const _missPrefix = 'MISS:';
  static const _missTtlMs = 24 * 60 * 60 * 1000; // retry a miss after 24h

  static const _base = 'https://www.thesportsdb.com/api/v1/json/3/searchplayers.php';

  /// Backend origin (same default as ApiService). Player images are streamed
  /// through it so they load under our CORS headers — TheSportsDB's R2 CDN
  /// sends no `Access-Control-Allow-Origin`, which breaks images on Flutter web.
  static const _apiBase =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000/api');

  /// Wrap a remote image URL so it streams through our backend proxy.
  static String proxied(String url) =>
      '$_apiBase/photos/proxy?url=${Uri.encodeComponent(_normalizeHost(url))}';

  /// TheSportsDB migrated player images to the r2 CDN; the old www host 404s now.
  static String _normalizeHost(String url) => url
      .replaceFirst('www.thesportsdb.com/images', 'r2.thesportsdb.com/images')
      .replaceFirst('https://thesportsdb.com/images', 'https://r2.thesportsdb.com/images');

  /// Returns a photo URL for the given player name, or null if not found.
  /// A successful URL is cached permanently; a miss is cached for [_missTtlMs]
  /// only (so it retries later instead of failing forever).
  static Future<String?> getPhoto(String playerName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${_slug(playerName)}';

    final cached = prefs.getString(key);
    if (cached != null && cached.isNotEmpty) {
      if (!cached.startsWith(_missPrefix)) return cached; // cached hit
      final ts = int.tryParse(cached.substring(_missPrefix.length)) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts < _missTtlMs) {
        return null; // recent miss — don't hammer the API
      }
      // stale miss → fall through and retry
    }

    try {
      final res = await _dio.get(_base, queryParameters: {'p': playerName});
      final players = res.data['player'] as List?;
      var url = (players != null && players.isNotEmpty)
          ? ((players.first as Map<String, dynamic>)['strThumb'] as String?)?.trim() ?? ''
          : '';
      if (url.isEmpty) {
        await prefs.setString(key, '$_missPrefix${DateTime.now().millisecondsSinceEpoch}');
        return null;
      }
      url = _normalizeHost(url);
      await prefs.setString(key, url);
      return url;
    } catch (_) {
      await prefs.setString(key, '$_missPrefix${DateTime.now().millisecondsSinceEpoch}');
      return null;
    }
  }

  /// Returns full bio (photo + dob + height + weight + position + club) for a
  /// player name, parsed from the same TheSportsDB response. Cached.
  static Future<PlayerInfo?> getInfo(String playerName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_infoPrefix${_slug(playerName)}';

    final cached = prefs.getString(key);
    if (cached != null && cached.isNotEmpty) {
      if (cached.startsWith(_missPrefix)) {
        final ts = int.tryParse(cached.substring(_missPrefix.length)) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - ts < _missTtlMs) return null;
      } else {
        try {
          return PlayerInfo.fromCache(jsonDecode(cached) as Map<String, dynamic>);
        } catch (_) {/* fall through */}
      }
    }

    try {
      final res = await _dio.get(_base, queryParameters: {'p': playerName});
      final players = res.data['player'] as List?;
      if (players == null || players.isEmpty) {
        await prefs.setString(key, '$_missPrefix${DateTime.now().millisecondsSinceEpoch}');
        return null;
      }
      final p = players.first as Map<String, dynamic>;
      final rawThumb = (p['strThumb'] as String?)?.trim();
      final info = PlayerInfo(
        photoUrl: (rawThumb != null && rawThumb.isNotEmpty) ? _normalizeHost(rawThumb) : null,
        dateOfBirth: _parseDob(p['dateBorn']),
        heightCm: _parseHeightCm(p['strHeight']),
        weightKg: _parseWeightKg(p['strWeight']),
        position: (p['strPosition'] as String?)?.trim(),
        club: (p['strTeam'] as String?)?.trim(),
      );
      await prefs.setString(key, jsonEncode(info.toCache()));
      return info;
    } catch (_) {
      await prefs.setString(key, '$_missPrefix${DateTime.now().millisecondsSinceEpoch}');
      return null;
    }
  }

  static String _slug(String s) => s.toLowerCase().replaceAll(' ', '_');

  static DateTime? _parseDob(dynamic v) {
    if (v is String && v.length >= 10) return DateTime.tryParse(v.substring(0, 10));
    return null;
  }

  // "1.85 m (6 ft 1 in)" | "1.85m" | "185 cm" → cm
  static int? _parseHeightCm(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    final m = RegExp(r'(\d\.\d{1,2})\s*m').firstMatch(v);
    if (m != null) return (double.parse(m.group(1)!) * 100).round();
    final cm = RegExp(r'(\d{3})\s*cm').firstMatch(v);
    if (cm != null) return int.parse(cm.group(1)!);
    return null;
  }

  // "78 kg (172 lbs)" | "78kg" → kg
  static int? _parseWeightKg(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    final m = RegExp(r'(\d{2,3})\s*kg').firstMatch(v);
    if (m != null) return int.parse(m.group(1)!);
    return null;
  }

  /// Clears cached photos + info (for testing/reset).
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith(_infoPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
