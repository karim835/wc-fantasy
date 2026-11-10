import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../utils/haptics.dart';

class FantasyHubScreen extends StatelessWidget {
  const FantasyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = [
      _HubItem(l.draft, Icons.people, AppColors.gold, '/draft',
          l.fantasy),
      _HubItem(l.leagues, Icons.emoji_events, AppColors.goldBright, '/leagues',
          l.fantasy),
      _HubItem(l.gameweeks, Icons.calendar_today, AppColors.info, '/gameweeks',
          l.fantasy),
      _HubItem(l.fixtures, Icons.stadium, const Color(0xFF22C55E), '/fixtures',
          l.fantasy),
      _HubItem(l.players, Icons.sports_soccer, AppColors.success, '/players',
          l.fantasy),
      _HubItem(l.battles, Icons.flash_on, AppColors.red, '/leagues',
          l.fantasy),
      _HubItem(l.predictions, Icons.psychology, const Color(0xFF8B5CF6), '/gameweeks',
          l.fantasy),
    ];

    return Scaffold(
      appBar: BrandAppBar(title: Text(l.fantasy)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.fantasy,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.fantasySubtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _HubCard(item: items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubItem {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final String category;
  const _HubItem(this.label, this.icon, this.color, this.route, this.category);
}

class _HubCard extends StatelessWidget {
  final _HubItem item;
  const _HubCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.light();
          context.go(item.route);
        },
        child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
