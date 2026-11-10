import 'dart:convert';

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Coerce any JSON value to a String? — never throws even if the backend
/// unexpectedly returns a number/object where a string was expected.
String? _str(dynamic v) => v == null ? null : (v is String ? v : v.toString());

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

/// Accept `stats` as a Map, a JSON-encoded String, or anything else (→ {}).
Map<String, dynamic> _toStatsMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String && v.isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return {};
}

class Player {
  final String id;
  final String name;
  final String position;
  final String? club;
  final String? nationality;
  final double price;
  final int points;
  final double form;
  final String? injuryStatus;
  final Map<String, dynamic> stats;
  final String? photoUrl;
  final DateTime? dateOfBirth;
  final int? heightCm;
  final int? weightKg;

  const Player({
    required this.id,
    required this.name,
    required this.position,
    this.club,
    this.nationality,
    this.price = 0,
    this.points = 0,
    this.form = 0,
    this.injuryStatus,
    this.stats = const {},
    this.photoUrl,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: _str(json['id']) ?? '',
        name: _str(json['name']) ?? '',
        position: _str(json['position']) ?? '',
        club: _str(json['club']),
        nationality: _str(json['nationality']),
        price: _toDouble(json['price']),
        points: _toInt(json['points']),
        form: _toDouble(json['form']),
        injuryStatus: _str(json['injury_status']),
        stats: _toStatsMap(json['stats']),
        photoUrl: _str(json['photo_url']),
        dateOfBirth: _toDate(json['date_of_birth']),
        heightCm: _toIntOrNull(json['height_cm']),
        weightKg: _toIntOrNull(json['weight_kg']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position,
        'club': club,
        'nationality': nationality,
        'price': price,
        'points': points,
        'form': form,
        'injury_status': injuryStatus,
        'stats': stats,
        'photo_url': photoUrl,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'height_cm': heightCm,
        'weight_kg': weightKg,
      };

  bool get isInjured =>
      injuryStatus != null && injuryStatus!.toLowerCase() != 'fit';

  /// Age in years from [dateOfBirth], or null if unknown.
  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      a--;
    }
    return a;
  }

  String get positionColor {
    switch (position) {
      case 'GK':  return '#FFD700';
      case 'DEF': return '#4FC3F7';
      case 'MID': return '#66BB6A';
      case 'FWD': return '#EF5350';
      default:    return '#FFFFFF';
    }
  }

  String get priceLabel => '\$${price.toStringAsFixed(1)}M';
}
