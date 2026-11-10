import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/player_photo.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_empty_state.dart';
import 'player_detail_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/player.dart';

class PlayersScreen extends StatefulWidget {
  /// When set, the list is pre-filtered to this nationality (from Nations tab).
  final String? initialNationality;
  const PlayersScreen({super.key, this.initialNationality});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Player> _players = [];
  String? _selectedPos;
  String? _selectedNationality;
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  // Advanced filters
  bool _showFilters = false;
  RangeValues _priceRange = const RangeValues(0, 20);
  double _minForm = 0;
  String? _availability; // null=all, 'available', 'injured'
  String _sort = 'points'; // points | price | form | name

  static const _positions = ['GK', 'DEF', 'MID', 'FWD'];
  static const _posColors = {
    'GK': Color(0xFFFFA726),
    'DEF': Color(0xFF42A5F5),
    'MID': Color(0xFF66BB6A),
    'FWD': Color(0xFFEF5350),
  };

  bool get _hasActiveFilters =>
      _priceRange.start > 0 ||
      _priceRange.end < 20 ||
      _minForm > 0 ||
      _availability != null;

  @override
  void initState() {
    super.initState();
    analyticsService.logScreen('players');
    _selectedNationality = widget.initialNationality;
    _loadPlayers(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) _loadPlayers();
    }
  }

  Future<void> _loadPlayers({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() { _players = []; _page = 1; _hasMore = true; _error = null; });
    }
    setState(() => _isLoading = true);
    try {
      final result = await apiService.getPlayers(
        position: _selectedPos,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        nationality: _selectedNationality,
        sort: _sort,
        page: _page,
        limit: 20,
      );
      final rawList = (result['players'] as List?) ?? const [];
      // Parse through the robust Player.fromJson (handles DECIMAL-as-string,
      // JSONB stats, nulls) so no raw cast can ever crash the screen.
      List<Player> newPlayers =
          rawList.map((j) => Player.fromJson(j as Map<String, dynamic>)).toList();

      // Client-side advanced filters (typed)
      newPlayers = newPlayers.where((p) {
        if (p.price < _priceRange.start || p.price > _priceRange.end) return false;
        if (p.form < _minForm) return false;
        if (_availability == 'available' && p.isInjured) return false;
        if (_availability == 'injured' && !p.isInjured) return false;
        return true;
      }).toList();

      setState(() {
        _players.addAll(newPlayers);
        // Base pagination on the raw page size, not the filtered count.
        _hasMore = rawList.length == 20;
        _page++;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String _) => _loadPlayers(reset: true);

  void _selectPos(String? pos) {
    setState(() => _selectedPos = pos);
    _loadPlayers(reset: true);
  }

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 20);
      _minForm = 0;
      _availability = null;
    });
    _loadPlayers(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: BrandAppBar(
        title: Text(_selectedNationality != null
            ? '${flagEmoji(_selectedNationality)} $_selectedNationality'
            : l.players),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: l.comparePlayers,
            onPressed: () => context.push('/compare'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: l.sortBy,
            color: AppColors.surface,
            initialValue: _sort,
            onSelected: (v) {
              setState(() => _sort = v);
              _loadPlayers(reset: true);
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'points', checked: _sort == 'points', child: Text(l.sortPoints, style: const TextStyle(color: Colors.white))),
              CheckedPopupMenuItem(value: 'price', checked: _sort == 'price', child: Text(l.sortPrice, style: const TextStyle(color: Colors.white))),
              CheckedPopupMenuItem(value: 'form', checked: _sort == 'form', child: Text(l.sortForm, style: const TextStyle(color: Colors.white))),
              CheckedPopupMenuItem(value: 'name', checked: _sort == 'name', child: Text(l.sortName, style: const TextStyle(color: Colors.white))),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
                  color: _hasActiveFilters ? AppColors.gold : null,
                ),
                tooltip: 'Filtres avancés',
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showFilters ? 210 : 110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un joueur...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadPlayers(reset: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    _PosChip(
                      label: l.allPositions,
                      color: Colors.white54,
                      selected: _selectedPos == null,
                      onTap: () => _selectPos(null),
                    ),
                    ..._positions.map((pos) => _PosChip(
                          label: pos,
                          color: _posColors[pos]!,
                          selected: _selectedPos == pos,
                          onTap: () => _selectPos(_selectedPos == pos ? null : pos),
                        )),
                  ],
                ),
              ),
              // Advanced filters panel
              if (_showFilters)
                _AdvancedFiltersPanel(
                  priceRange: _priceRange,
                  minForm: _minForm,
                  availability: _availability,
                  hasActive: _hasActiveFilters,
                  onPriceChanged: (v) => setState(() => _priceRange = v),
                  onFormChanged: (v) => setState(() => _minForm = v),
                  onAvailabilityChanged: (v) {
                    setState(() => _availability = v);
                    _loadPlayers(reset: true);
                  },
                  onApply: () => _loadPlayers(reset: true),
                  onReset: _resetFilters,
                ),
            ],
          ),
        ),
      ),
      body: _error != null && _players.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _loadPlayers(reset: true),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : _players.isEmpty && !_isLoading
              ? const AppEmptyState.noPlayers()
              : _players.isEmpty && _isLoading
                  ? const PlayerListSkeleton()
                  : RefreshIndicator(
                      onRefresh: () => _loadPlayers(reset: true),
                      color: AppColors.gold,
                      child: ListView.separated(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _players.length + (_isLoading || _hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          if (i >= _players.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: PlayerCardSkeleton(),
                            );
                          }
                          final p = _players[i];
                          return _PlayerCard(player: p)
                              .animate(delay: Duration(milliseconds: (i % 20) * 30))
                              .fadeIn(duration: 250.ms)
                              .slideY(begin: 0.1, end: 0, duration: 250.ms, curve: Curves.easeOut);
                        },
                      ),
                    ),
    );
  }
}

// ─── Advanced filters panel ───────────────────────────────────────────────────

class _AdvancedFiltersPanel extends StatelessWidget {
  final RangeValues priceRange;
  final double minForm;
  final String? availability;
  final bool hasActive;
  final ValueChanged<RangeValues> onPriceChanged;
  final ValueChanged<double> onFormChanged;
  final ValueChanged<String?> onAvailabilityChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  const _AdvancedFiltersPanel({
    required this.priceRange,
    required this.minForm,
    required this.availability,
    required this.hasActive,
    required this.onPriceChanged,
    required this.onFormChanged,
    required this.onAvailabilityChanged,
    required this.onApply,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price range
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text(
                'Prix: ${priceRange.start.toStringAsFixed(0)}M — ${priceRange.end.toStringAsFixed(0)}M',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              if (hasActive)
                GestureDetector(
                  onTap: onReset,
                  child: Text(l.resetFilters,
                      style: const TextStyle(color: AppColors.gold, fontSize: 11)),
                ),
            ],
          ),
          RangeSlider(
            values: priceRange,
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: AppColors.gold,
            inactiveColor: Colors.white12,
            onChanged: onPriceChanged,
            onChangeEnd: (_) => onApply(),
            labels: RangeLabels(
              '${priceRange.start.toStringAsFixed(0)}M',
              '${priceRange.end.toStringAsFixed(0)}M',
            ),
          ),
          // Form slider
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text(
                'Forme min.: ${minForm.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: minForm,
            min: 0,
            max: 10,
            divisions: 20,
            activeColor: const Color(0xFF66BB6A),
            inactiveColor: Colors.white12,
            label: minForm.toStringAsFixed(1),
            onChanged: onFormChanged,
            onChangeEnd: (_) => onApply(),
          ),
          // Availability chips
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              _AvailChip(
                label: l.allPositions,
                selected: availability == null,
                color: Colors.white54,
                onTap: () => onAvailabilityChanged(null),
              ),
              const SizedBox(width: 6),
              _AvailChip(
                label: l.available,
                selected: availability == 'available',
                color: Colors.greenAccent,
                onTap: () => onAvailabilityChanged('available'),
              ),
              const SizedBox(width: 6),
              _AvailChip(
                label: l.injured,
                selected: availability == 'injured',
                color: Colors.redAccent,
                onTap: () => onAvailabilityChanged('injured'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _AvailChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? color : Colors.white38,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }
}

// ─── Position filter chip ─────────────────────────────────────────────────────

class _PosChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PosChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

// ─── Player card ──────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Player player;
  const _PlayerCard({required this.player});

  static const _posColors = {
    'GK': Color(0xFFFFA726),
    'DEF': Color(0xFF42A5F5),
    'MID': Color(0xFF66BB6A),
    'FWD': Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final pos = player.position.isEmpty ? 'MID' : player.position;
    final posColor = _posColors[pos] ?? Colors.white54;
    final isInjured = player.isInjured;
    final priceFmt = '${player.price.toStringAsFixed(2)} M€';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isInjured ? Colors.redAccent.withValues(alpha: 0.5) : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            // Photo with flag badge
            PlayerPhoto(
              name: player.name,
              photoUrl: player.photoUrl,
              nationality: player.nationality,
              showFlag: true,
              radius: 28,
            ),
            const SizedBox(width: 14),
            // Name / position / club / price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isInjured) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.medical_services, color: Colors.redAccent, size: 13),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: posColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: posColor.withValues(alpha: 0.5), width: 0.5),
                        ),
                        child: Text(pos,
                            style: TextStyle(
                                color: posColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          player.club ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceFmt,
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Large points number
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${player.points}',
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 28),
                ),
                const Text('pts',
                    style: TextStyle(color: Colors.white54, fontSize: 11, height: 1)),
              ],
            ),
            const SizedBox(width: 10),
            // Red "+" button
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
