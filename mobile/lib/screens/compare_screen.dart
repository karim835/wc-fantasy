import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/player.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/player_photo.dart';

/// Side-by-side comparison of two players. Pick each via a search sheet.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  Player? _a;
  Player? _b;

  Future<void> _pick(bool isLeft) async {
    final player = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _PlayerSearchSheet(),
    );
    if (player != null) {
      setState(() => isLeft ? _a = player : _b = player);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: BrandAppBar(title: Text(l.comparePlayers)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _slot(_a, true, l)),
              const SizedBox(width: 12),
              Expanded(child: _slot(_b, false, l)),
            ],
          ),
          const SizedBox(height: 20),
          if (_a != null && _b != null) _table(_a!, _b!, l)
          else Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text(l.selectTwoPlayers, style: const TextStyle(color: Colors.white54))),
          ),
        ],
      ),
    );
  }

  Widget _slot(Player? p, bool isLeft, AppLocalizations l) {
    return GestureDetector(
      onTap: () => _pick(isLeft),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: p == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline, color: AppColors.gold, size: 36),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(l.addPlayer, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayerPhoto(name: p.name, photoUrl: p.photoUrl, nationality: p.nationality, radius: 34),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(p.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Text('${p.position} · ${p.club ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
      ),
    );
  }

  Widget _table(Player a, Player b, AppLocalizations l) {
    final rows = <_CmpRow>[
      _CmpRow(l.sortPrice, '${a.price.toStringAsFixed(1)}M', '${b.price.toStringAsFixed(1)}M', a.price, b.price, higherWins: false),
      _CmpRow(l.sortPoints, '${a.points}', '${b.points}', a.points.toDouble(), b.points.toDouble()),
      _CmpRow(l.sortForm, a.form.toStringAsFixed(1), b.form.toStringAsFixed(1), a.form, b.form),
      _CmpRow(l.position, a.position, b.position, 0, 0, numeric: false),
      if (a.age != null || b.age != null) _CmpRow(l.age, '${a.age ?? '—'}', '${b.age ?? '—'}', 0, 0, numeric: false),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: rows.map((r) => _tableRow(r)).toList()),
    );
  }

  Widget _tableRow(_CmpRow r) {
    final aWins = r.numeric && (r.higherWins ? r.aVal > r.bVal : r.aVal < r.bVal);
    final bWins = r.numeric && (r.higherWins ? r.bVal > r.aVal : r.bVal < r.aVal);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(r.aText, textAlign: TextAlign.center, style: TextStyle(color: aWins ? AppColors.gold : Colors.white, fontWeight: aWins ? FontWeight.bold : FontWeight.normal))),
          Expanded(child: Text(r.label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12))),
          Expanded(child: Text(r.bText, textAlign: TextAlign.center, style: TextStyle(color: bWins ? AppColors.gold : Colors.white, fontWeight: bWins ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}

class _CmpRow {
  final String label;
  final String aText;
  final String bText;
  final double aVal;
  final double bVal;
  final bool higherWins;
  final bool numeric;
  _CmpRow(this.label, this.aText, this.bText, this.aVal, this.bVal, {this.higherWins = true, this.numeric = true});
}

class _PlayerSearchSheet extends StatefulWidget {
  const _PlayerSearchSheet();

  @override
  State<_PlayerSearchSheet> createState() => _PlayerSearchSheetState();
}

class _PlayerSearchSheetState extends State<_PlayerSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Player> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await apiService.getPlayers(search: q.isEmpty ? null : q, limit: 30, sort: 'points');
      final list = ((res['players'] as List?) ?? const []).map((j) => Player.fromJson(j as Map<String, dynamic>)).toList();
      if (mounted) setState(() { _results = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l.searchPlaceholder,
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: PlayerPhoto(name: p.name, photoUrl: p.photoUrl, nationality: p.nationality, radius: 18),
                        title: Text(p.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${p.position} · ${p.club ?? ''} · ${p.points} pts', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: Text('${p.price.toStringAsFixed(1)}M', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
