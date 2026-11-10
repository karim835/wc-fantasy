
class RiskScore {
  final String playerId;
  final double riskScore;
  final String riskLabel;
  final List<String> factors;
  final String recommendation;

  const RiskScore({
    required this.playerId,
    required this.riskScore,
    required this.riskLabel,
    required this.factors,
    required this.recommendation,
  });

  factory RiskScore.fromJson(Map<String, dynamic> json) {
    final risk = json['risk'] as Map<String, dynamic>? ?? json;
    return RiskScore(
      playerId: risk['player_id'] as String? ?? '',
      riskScore: (risk['risk_score'] as num?)?.toDouble() ?? 0.0,
      riskLabel: risk['risk_label'] as String? ?? 'Unknown',
      factors: (risk['factors'] as List<dynamic>?)
              ?.map((f) => f as String)
              .toList() ??
          [],
      recommendation: risk['recommendation'] as String? ?? '',
    );
  }

  bool get isLowRisk => riskScore <= 2;
  bool get isHighRisk => riskScore >= 7;
}

class TransferSuggestion {
  final Map<String, dynamic> playerIn;
  final Map<String, dynamic> playerOut;
  final double netCost;
  final double projectedPointGain;
  final double valueScore;

  const TransferSuggestion({
    required this.playerIn,
    required this.playerOut,
    required this.netCost,
    required this.projectedPointGain,
    required this.valueScore,
  });

  factory TransferSuggestion.fromJson(Map<String, dynamic> json) =>
      TransferSuggestion(
        playerIn: json['player_in'] as Map<String, dynamic>? ?? {},
        playerOut: json['player_out'] as Map<String, dynamic>? ?? {},
        netCost: (json['net_cost'] as num?)?.toDouble() ?? 0.0,
        projectedPointGain:
            (json['projected_point_gain'] as num?)?.toDouble() ?? 0.0,
        valueScore: (json['value_score'] as num?)?.toDouble() ?? 0.0,
      );

  String get playerInName => playerIn['name'] as String? ?? '?';
  String get playerOutName => playerOut['name'] as String? ?? '?';
  String get netCostLabel => netCost >= 0 ? '+\$${netCost}M' : '-\$${netCost.abs()}M';
}
