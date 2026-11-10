import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../utils/haptics.dart';

class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final items = [
      _MoreItem(l.profile, Icons.person_outline, '/profile'),
      _MoreItem(l.friends, Icons.group_outlined, '/friends'),
      _MoreItem(l.players, Icons.sports_soccer, '/players'),
      _MoreItem(l.nations, Icons.flag_outlined, '/nations'),
      _MoreItem(l.challenges, Icons.military_tech_outlined, '/challenges'),
      _MoreItem(l.howToPlay, Icons.help_outline, '/rules'),
      _MoreItem(l.seasonWrapped, Icons.bar_chart, '/wrapped'),
      _MoreItem(l.settings, Icons.settings_outlined, '/settings'),
    ];

    return Scaffold(
      appBar: BrandAppBar(title: Text(l.more)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _MoreTile(item: items[i]),
      ),
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final String route;
  const _MoreItem(this.label, this.icon, this.route);
}

class _MoreTile extends StatelessWidget {
  final _MoreItem item;
  const _MoreTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.light();
          context.push(item.route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(item.icon, color: AppColors.gold, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
