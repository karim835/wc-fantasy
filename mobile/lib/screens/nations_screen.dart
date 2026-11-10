import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/player_avatar.dart' show flagEmoji;
import '../widgets/skeleton_loader.dart';
import '../utils/haptics.dart';

/// Lists every nationality that actually has players (data-driven, so names
/// always match the DB). Tapping a nation opens the Players list filtered to it.
class NationsScreen extends StatefulWidget {
  const NationsScreen({super.key});

  @override
  State<NationsScreen> createState() => _NationsScreenState();
}

class _NationsScreenState extends State<NationsScreen> {
  String _search = '';
  List<Map<String, dynamic>> _nations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await apiService.getNationalities();
      if (!mounted) return;
      setState(() {
        _nations = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final filtered = _nations
        .where((n) => (n['nationality'] as String? ?? '')
            .toLowerCase()
            .contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(l.nations),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l.search,
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const PlayerListSkeleton()
          : _error != null
              ? AppErrorWidget(onRetry: _load)
              : filtered.isEmpty
                  ? AppEmptyState(title: l.noData, icon: Icons.search_off_outlined)
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final nation = filtered[i]['nationality'] as String? ?? '';
                        final count = filtered[i]['count'] ?? 0;
                        return Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Haptics.light();
                              context.push('/players', extra: nation);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Text(flagEmoji(nation), style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      nation,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text('$count', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
