class User {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final int totalPoints;
  final int? rank;
  final DateTime? createdAt;
  final String? role;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.totalPoints = 0,
    this.rank,
    this.createdAt,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        rank: (json['rank'] as num?)?.toInt(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        role: json['role'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'total_points': totalPoints,
        'rank': rank,
        'created_at': createdAt?.toIso8601String(),
        'role': role,
      };

  String get initials => username.isNotEmpty ? username[0].toUpperCase() : '?';

  bool get isAdmin => role == 'admin';

  User copyWith({
    String? username,
    String? avatarUrl,
    int? totalPoints,
    int? rank,
  }) =>
      User(
        id: id,
        username: username ?? this.username,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        totalPoints: totalPoints ?? this.totalPoints,
        rank: rank ?? this.rank,
        createdAt: createdAt,
        role: role,
      );
}
