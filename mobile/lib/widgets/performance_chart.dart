import 'package:fl_chart/fl_chart.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Graphique de performance — LineChart avec fl_chart (100% gratuit)
/// Affiche l'évolution des points par gameweek
class PerformanceChart extends StatefulWidget {
  final List<dynamic> gwHistory;
  final String title;
  final Color lineColor;

  const PerformanceChart({
    super.key,
    required this.gwHistory,
    this.title = 'Points par Gameweek',
    this.lineColor = AppColors.gold,
  });

  @override
  State<PerformanceChart> createState() => _PerformanceChartState();
}

class _PerformanceChartState extends State<PerformanceChart> {
  int? _touchedIndex;

  List<FlSpot> get _spots {
    return widget.gwHistory.asMap().entries.map((e) {
      final pts = (e.value['gw_points'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), pts);
    }).toList();
  }

  double get _maxY {
    if (_spots.isEmpty) return 100;
    final max = _spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return (max * 1.3).ceilToDouble().clamp(10.0, double.infinity);
  }

  double get _avgPoints {
    if (_spots.isEmpty) return 0;
    return _spots.map((s) => s.y).reduce((a, b) => a + b) / _spots.length;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gwHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header avec stats rapides
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            _ChartBadge(
              label: 'Moy',
              value: _avgPoints.toStringAsFixed(1),
              color: widget.lineColor,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Le graphique
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: _maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: (_maxY / 4).roundToDouble(),
                    getTitlesWidget: (value, _) => Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= widget.gwHistory.length) return const SizedBox.shrink();
                      final gw = widget.gwHistory[idx]['number']?.toString() ?? '';
                      return Text(
                        'GW$gw',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (_, response) {
                  setState(() {
                    _touchedIndex = response?.lineBarSpots?.first.spotIndex;
                  });
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surface,
                  getTooltipItems: (spots) => spots.map((s) {
                    final gw = widget.gwHistory[s.spotIndex]['number'] ?? '';
                    return LineTooltipItem(
                      'GW$gw\n${s.y.toInt()} pts',
                      TextStyle(
                        color: widget.lineColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                // Zone remplie sous la courbe
                LineChartBarData(
                  spots: _spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: widget.lineColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, index) => FlDotCirclePainter(
                      radius: index == _touchedIndex ? 6 : 3.5,
                      color: widget.lineColor,
                      strokeColor: AppColors.background,
                      strokeWidth: 2,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        widget.lineColor.withValues(alpha: 0.25),
                        widget.lineColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Ligne de moyenne
                LineChartBarData(
                  spots: _spots.isNotEmpty
                      ? [FlSpot(0, _avgPoints), FlSpot((_spots.length - 1).toDouble(), _avgPoints)]
                      : [],
                  color: Colors.white.withValues(alpha: 0.2),
                  barWidth: 1,
                  dotData: const FlDotData(show: false),
                  dashArray: [6, 4],
                ),
              ],
            ),
            duration: const Duration(milliseconds: 600),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
  }
}

class _ChartBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ChartBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── BarChart — Comparaison top joueurs ──────────────────────────────────────

class TopPlayersBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> players; // [{name, points, position}]
  final String title;

  const TopPlayersBarChart({
    super.key,
    required this.players,
    this.title = 'Top Joueurs',
  });

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK':  return AppColors.warning;
      case 'DEF': return AppColors.success;
      case 'MID': return AppColors.info;
      case 'FWD': return AppColors.red;
      default:    return const Color(0xFF8b5cf6);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    final maxPts = players.map((p) => (p['points'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: (maxPts * 1.3).ceilToDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= players.length) return const SizedBox.shrink();
                      final name = (players[idx]['name'] as String? ?? '');
                      final short = name.length > 7 ? '${name.substring(0, 6)}.' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          short,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surface,
                  getTooltipItem: (group, _, rod, __) {
                    final p = players[group.x];
                    return BarTooltipItem(
                      '${p['name']}\n${rod.toY.toInt()} pts',
                      TextStyle(
                        color: _posColor(p['position'] as String? ?? ''),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ),
              barGroups: players.asMap().entries.map((e) {
                final pos = e.value['position'] as String? ?? '';
                final pts = (e.value['points'] as num?)?.toDouble() ?? 0;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: pts,
                      gradient: LinearGradient(
                        colors: [_posColor(pos), _posColor(pos).withValues(alpha: 0.5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, delay: 100.ms);
  }
}
