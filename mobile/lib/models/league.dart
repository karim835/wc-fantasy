// Safe parsers — handle String or num from API
int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class League {
  final String id;
  final String name;
  final String ownerId;
  final int maxMembers;
  final bool isPrivate;
  final String? inviteCode;
  final String? season;
  final String status;
  final int memberCount;
  final int myPoints;
  final List<LeagueMember> members;
  final DateTime? createdAt;

  const League({
    required this.id,
    required this.name,
    required this.ownerId,
    this.maxMembers = 10,
    this.isPrivate = false,
    this.inviteCode,
    this.season,
    this.status = 'active',
    this.memberCount = 0,
    this.myPoints = 0,
    this.members = const [],
    this.createdAt,
  });

  factory League.fromJson(Map<String, dynamic> json) => League(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['owner_id'] as String,
        maxMembers: _toInt(json['max_members'], 10),
        isPrivate: json['is_private'] as bool? ?? false,
        inviteCode: json['invite_code'] as String?,
        season: json['season'] as String?,
        status: json['status'] as String? ?? 'active',
        memberCount: _toInt(json['member_count']),
        myPoints: _toInt(json['my_points']),
        members: (json['members'] as List<dynamic>?)
                ?.map((m) => LeagueMember.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  String get initials => name.isNotEmpty ? name[0].toUpperCase() : 'L';

  bool get isFull => memberCount >= maxMembers;

  bool get isActive => status == 'active';
}

class LeagueMember {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int points;

  const LeagueMember({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.points = 0,
  });

  factory LeagueMember.fromJson(Map<String, dynamic> json) => LeagueMember(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        points: _toInt(json['points']),
      );

  String get initials => username.isNotEmpty ? username[0].toUpperCase() : '?';
}

class LeaderboardEntry {
  final String id;
  final String username;
  final String? avatarUrl;
  final int points;
  final int rank;

  const LeaderboardEntry({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.points,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        id: json['id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        points: _toInt(json['points']),
        rank: _toInt(json['rank']),
      );

  String get initials => username.isNotEmpty ? username[0].toUpperCase() : '?';
}
