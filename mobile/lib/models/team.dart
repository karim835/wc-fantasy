
class Team {
  final String id;
  final String userId;
  final String leagueId;
  final String name;
  final double budget;
  final String formation;
  final List<TeamPlayer> players;
  final int totalPoints;
  final DateTime? updatedAt;

  const Team({
    required this.id,
    required this.userId,
    required this.leagueId,
    required this.name,
    this.budget = 100.0,
    this.formation = '4-3-3',
    this.players = const [],
    this.totalPoints = 0,
    this.updatedAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        leagueId: json['league_id'] as String,
        name: json['name'] as String,
        budget: (json['budget'] as num?)?.toDouble() ?? 100.0,
        formation: json['formation'] as String? ?? '4-3-3',
        players: (json['players'] as List<dynamic>?)
                ?.map((p) => TeamPlayer.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  int get playerCount => players.length;

  bool get isFull => playerCount >= 15;

  List<TeamPlayer> byPosition(String position) =>
      players.where((p) => p.position == position).toList();

  String get budgetLabel => '\$${budget.toStringAsFixed(1)}M';
}

class TeamPlayer {
  final String id;
  final String name;
  final String position;

  const TeamPlayer({
    required this.id,
    required this.name,
    required this.position,
  });

  factory TeamPlayer.fromJson(Map<String, dynamic> json) => TeamPlayer(
        id: json['id'] as String,
        name: json['name'] as String,
        position: json['position'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position,
      };
}
