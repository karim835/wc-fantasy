import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_app_bar.dart';

/// "How to play" / scoring rules. Static reference content — the numbers mirror
/// the POINTS table in controllers/gameweek.controller.js. Keep them in sync if
/// the backend scoring ever changes.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: BrandAppBar(title: Text(l.howToPlay)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.rulesIntro, style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14)),
          const SizedBox(height: 20),

          _Section(
            icon: Icons.groups,
            title: l.rulesSquadTitle,
            child: Text(l.rulesSquadBody, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ),

          _Section(
            icon: Icons.scoreboard_outlined,
            title: l.rulesPointsTitle,
            child: _PointsTable(l: l),
          ),

          _Section(
            icon: Icons.star_outline,
            title: l.rulesBonusTitle,
            child: Column(
              children: [
                _BonusRow(l.bonusHatTrick, '+5'),
                _BonusRow(l.bonusPenSave, '+5'),
                _BonusRow(l.bonusPenMiss, '-2'),
                _BonusRow(l.bonusOwnGoal, '-2'),
                _BonusRow(l.captain, '×2'),
              ],
            ),
          ),

          _Section(
            icon: Icons.bolt,
            title: l.rulesChipsTitle,
            child: Column(
              children: [
                _ChipRow(Icons.local_fire_department, l.chipTripleCaptain, l.chipTripleCaptainDesc),
                _ChipRow(Icons.change_circle_outlined, l.chipSuperSub, l.chipSuperSubDesc),
                _ChipRow(Icons.shield_outlined, l.chipShield, l.chipShieldDesc),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Section({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PointsTable extends StatelessWidget {
  final AppLocalizations l;
  const _PointsTable({required this.l});

  @override
  Widget build(BuildContext context) {
    // Rows: label + [GK, DEF, MID, FWD]
    final rows = <List<String>>[
      [l.actionPlaying60, '2', '2', '2', '2'],
      [l.actionPlayingSub, '1', '1', '1', '1'],
      [l.actionGoal, '10', '6', '5', '4'],
      [l.actionAssist, '6', '3', '3', '3'],
      [l.actionCleanSheet, '6', '4', '1', '0'],
      [l.actionYellow, '-1', '-1', '-1', '-1'],
      [l.actionRed, '-3', '-3', '-3', '-3'],
    ];

    Widget cell(String t, {bool header = false, bool first = false}) => Expanded(
          flex: first ? 4 : 2,
          child: Text(
            t,
            textAlign: first ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              color: header ? AppColors.goldBright : (first ? Colors.white70 : Colors.white),
              fontWeight: header ? FontWeight.bold : (first ? FontWeight.normal : FontWeight.w600),
              fontSize: 13,
            ),
          ),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            cell(l.colAction, header: true, first: true),
            cell('GK', header: true),
            cell('DEF', header: true),
            cell('MID', header: true),
            cell('FWD', header: true),
          ]),
        ),
        const Divider(color: Colors.white12, height: 1),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                cell(r[0], first: true),
                cell(r[1]),
                cell(r[2]),
                cell(r[3]),
                cell(r[4]),
              ]),
            )),
      ],
    );
  }
}

class _BonusRow extends StatelessWidget {
  final String label;
  final String value;
  const _BonusRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final positive = !value.startsWith('-');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: (positive ? AppColors.success : AppColors.red).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(color: positive ? AppColors.success : AppColors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String desc;
  const _ChipRow(this.icon, this.name, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.goldBright, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
