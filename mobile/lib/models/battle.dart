class Battle {
  final String id;
  final String leagueId;
  final String homeTeamId;
  final String awayTeamId;
  final String? homeTeamName;
  final String? awayTeamName;
  final String? homeUsername;
  final String? awayUsername;
  final int homeScore;
  final int awayScore;
  final String status;
  final int? gameweek;
  final List<dynamic> homePlayers;
  final List<dynamic> awayPlayers;
  final DateTime? createdAt;

  const Battle({
    required this.id,
    required this.leagueId,
    required this.homeTeamId,
    required this.awayTeamId,
    this.homeTeamName,
    this.awayTeamName,
    this.homeUsername,
    this.awayUsername,
    this.homeScore = 0,
    this.awayScore = 0,
    this.status = 'scheduled',
    this.gameweek,
    this.homePlayers = const [],
    this.awayPlayers = const [],
    this.createdAt,
  });

  factory Battle.fromJson(Map<String, dynamic> json) => Battle(
        id: json['id'] as String,
        leagueId: json['league_id'] as String,
        homeTeamId: json['home_team_id'] as String,
        awayTeamId: json['away_team_id'] as String,
        homeTeamName: json['home_team_name'] as String?,
        awayTeamName: json['away_team_name'] as String?,
        homeUsername: json['home_username'] as String?,
        awayUsername: json['away_username'] as String?,
        homeScore: (json['home_score'] as num?)?.toInt() ?? 0,
        awayScore: (json['away_score'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'scheduled',
        gameweek: (json['gameweek'] as num?)?.toInt(),
        homePlayers: (json['home_players'] as List<dynamic>?) ?? [],
        awayPlayers: (json['away_players'] as List<dynamic>?) ?? [],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  bool get isLive => status == 'live';
  bool get isFinished => status == 'finished';
  bool get isScheduled => status == 'scheduled';

  String get scoreLabel => '$homeScore - $awayScore';

  String? get winner {
    if (!isFinished) return null;
    if (homeScore > awayScore) return homeTeamId;
    if (awayScore > homeScore) return awayTeamId;
    return null; // draw
  }
}
