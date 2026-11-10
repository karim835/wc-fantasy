import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/league_provider.dart';
import '../services/api_service.dart';
import '../widgets/league_card.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/error_view.dart';
import '../l10n/app_localizations.dart';
import 'league_detail_screen.dart';

class LeaguesScreen extends ConsumerStatefulWidget {
  /// When opened via a /join/:code deep link, pre-fills + opens the join dialog.
  final String? initialJoinCode;
  const LeaguesScreen({super.key, this.initialJoinCode});

  @override
  ConsumerState<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends ConsumerState<LeaguesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(leagueProvider.notifier).loadLeagues();
      if (widget.initialJoinCode != null && mounted) {
        _showJoinLeague(initialCode: widget.initialJoinCode);
      }
    });
  }

  void _showCreateLeague() {
    final l = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    int maxMembers = 10;
    bool isPrivate = false;
    bool creating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.createLeague, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: l.leagueName,
                    labelStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
                    filled: true, fillColor: AppColors.background,
                    errorStyle: const TextStyle(color: Colors.redAccent),
                    counterText: '${nameCtrl.text.length}/50',
                  ),
                  maxLength: 50,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.nameRequired;
                    if (v.trim().length < 3) return l.min3chars;
                    if (v.trim().length > 50) return 'Maximum 50';
                    return null;
                  },
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('${l.maxMembers}:', style: const TextStyle(color: Colors.white54)),
                    const SizedBox(width: 12),
                    ...([4, 6, 8, 10, 12, 16].map((n) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$n'),
                        selected: maxMembers == n,
                        onSelected: (_) => setModalState(() => maxMembers = n),
                        selectedColor: AppColors.gold,
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(color: maxMembers == n ? Colors.black : Colors.white54, fontSize: 12),
                      ),
                    ))),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.privateLeague, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(l.privateLeagueHint, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  value: isPrivate,
                  activeThumbColor: AppColors.gold,
                  onChanged: (v) => setModalState(() => isPrivate = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: creating ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => creating = true);
                      final ok = await ref.read(leagueProvider.notifier).createLeague(
                        name: nameCtrl.text.trim(),
                        isPrivate: isPrivate,
                        maxMembers: maxMembers,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok != null ? '${l.createLeague} "${nameCtrl.text.trim()}" ✓' : ref.read(leagueProvider).error ?? l.errorCreating),
                          backgroundColor: ok != null ? Colors.green : Colors.red,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: creating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(l.create, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showJoinLeague({String? initialCode}) {
    final l = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: initialCode?.toUpperCase() ?? '');
    bool joining = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l.joinLeague, style: const TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: codeCtrl,
              style: const TextStyle(color: Colors.white, letterSpacing: 3, fontWeight: FontWeight.bold),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: l.leagueCode,
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'ex: AB12CD34',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
                filled: true, fillColor: AppColors.background,
                errorStyle: const TextStyle(color: Colors.redAccent),
                prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white38),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l.enterInviteCode;
                if (v.trim().length < 4) return l.invalidCode;
                return null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
              onPressed: joining ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => joining = true);
                final ok = await ref.read(leagueProvider.notifier).joinLeague(codeCtrl.text.trim().toUpperCase());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? l.leagueJoined : ref.read(leagueProvider).error ?? l.invalidCodeOrNotFound),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ));
                }
              },
              child: joining
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(l.join),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscover() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => FutureBuilder<List<dynamic>>(
          future: apiService.getPublicLeagues(),
          builder: (ctx, snap) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.publicLeagues, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: !snap.hasData
                      ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                      : (snap.data!.isEmpty)
                          ? Center(child: Text(l.noPublicLeagues, style: const TextStyle(color: Colors.white54)))
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: snap.data!.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final lg = snap.data![i] as Map<String, dynamic>;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.cardGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(lg['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                            Text('${lg['member_count']}/${lg['max_members']} · ${lg['season'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.onGold),
                                        onPressed: () async {
                                          try {
                                            await apiService.joinPublicLeague(lg['id'] as String);
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            await ref.read(leagueProvider.notifier).loadLeagues();
                                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.leagueJoined), backgroundColor: Colors.green));
                                          } catch (e) {
                                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e'), backgroundColor: Colors.red));
                                          }
                                        },
                                        child: Text(l.join),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leagueProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(l.myLeagues),
        actions: [
          IconButton(icon: const Icon(Icons.explore_outlined), onPressed: _showDiscover, tooltip: l.discoverLeagues),
          IconButton(icon: const Icon(Icons.group_add), onPressed: _showJoinLeague, tooltip: l.join),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLeague,
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text(l.create),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(leagueProvider.notifier).loadLeagues(),
        child: state.isLoading && state.leagues.isEmpty
            ? const LeagueListShimmer()
            : state.error != null && state.leagues.isEmpty
                ? ErrorView(message: state.error!, onRetry: () => ref.read(leagueProvider.notifier).loadLeagues())
                : state.leagues.isEmpty
                    ? EmptyView(
                        icon: Icons.emoji_events_outlined,
                        title: l.noLeaguesTitle,
                        subtitle: l.noLeaguesSubtitle,
                        action: ElevatedButton.icon(
                          onPressed: _showCreateLeague,
                          icon: const Icon(Icons.add),
                          label: Text(l.createLeague),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 12, bottom: 80),
                        itemCount: state.leagues.length,
                        itemBuilder: (_, i) => LeagueCard(
                          league: state.leagues[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeagueDetailScreen(league: state.leagues[i]),
                            ),
                          ),
                          onLeaderboard: () {
                            ref.read(leagueProvider.notifier).loadLeaderboard(state.leagues[i].id);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeagueDetailScreen(league: state.leagues[i], initialTab: 1),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
