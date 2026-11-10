import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/app_localizations.dart';

enum _EmptyKind { noTeam, noLeague, noPlayers, noNews, noBattles, noHistory, offline, error }

/// Widget d'état vide réutilisable — utilisé sur tous les écrans sans données.
///
/// Les variantes sémantiques (`AppEmptyState.noTeam()`, etc.) stockent un [kind]
/// et résolvent leurs textes (titre/sous-titre/action) en FR/EN au moment du
/// build via [AppLocalizations], pour rester traduisibles tout en gardant des
/// constructeurs `const` côté appelants.
class AppEmptyState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final _EmptyKind? kind;
  final String? errorMsg;

  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  })  : kind = null,
        errorMsg = null;

  // ── Constructeurs sémantiques (textes résolus dans build) ──────────────────

  const AppEmptyState.noTeam({super.key, VoidCallback? onDraft})
      : kind = _EmptyKind.noTeam,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = null,
        icon = Icons.group_add_outlined,
        onAction = onDraft,
        iconColor = AppColors.gold;

  const AppEmptyState.noLeague({super.key, VoidCallback? onCreate})
      : kind = _EmptyKind.noLeague,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = null,
        icon = Icons.emoji_events_outlined,
        onAction = onCreate,
        iconColor = AppColors.warning;

  const AppEmptyState.noPlayers({super.key, VoidCallback? onReset})
      : kind = _EmptyKind.noPlayers,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = null,
        icon = Icons.person_search_outlined,
        onAction = onReset,
        iconColor = AppColors.success;

  const AppEmptyState.noNews({super.key, VoidCallback? onRefresh})
      : kind = _EmptyKind.noNews,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = null,
        icon = Icons.article_outlined,
        onAction = onRefresh,
        iconColor = const Color(0xFF8B5CF6);

  const AppEmptyState.noBattles({super.key, VoidCallback? onRefresh})
      : kind = _EmptyKind.noBattles,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = null,
        icon = Icons.sports_kabaddi_outlined,
        onAction = onRefresh,
        iconColor = AppColors.red;

  const AppEmptyState.noHistory({super.key})
      : kind = _EmptyKind.noHistory,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = null,
        icon = Icons.bar_chart_outlined,
        onAction = null,
        iconColor = AppColors.gold;

  const AppEmptyState.offline({super.key, VoidCallback? onRetry})
      : kind = _EmptyKind.offline,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = null,
        icon = Icons.wifi_off_outlined,
        onAction = onRetry,
        iconColor = Colors.orange;

  const AppEmptyState.error({super.key, VoidCallback? onRetry, String? msg})
      : kind = _EmptyKind.error,
        title = null,
        subtitle = null,
        actionLabel = null,
        errorMsg = msg,
        icon = Icons.error_outline,
        onAction = onRetry,
        iconColor = Colors.red;

  // ── Localized text resolution ──────────────────────────────────────────────

  String _resolveTitle(AppLocalizations l) {
    switch (kind) {
      case _EmptyKind.noTeam:
        return l.emptyNoTeamTitle;
      case _EmptyKind.noLeague:
        return l.noLeaguesTitle;
      case _EmptyKind.noPlayers:
        return l.emptyNoPlayersTitle;
      case _EmptyKind.noNews:
        return l.emptyNoNewsTitle;
      case _EmptyKind.noBattles:
        return l.emptyNoBattlesTitle;
      case _EmptyKind.noHistory:
        return l.emptyNoHistoryTitle;
      case _EmptyKind.offline:
        return l.emptyOfflineTitle;
      case _EmptyKind.error:
        return l.emptyErrorTitle;
      case null:
        return '';
    }
  }

  String? _resolveSubtitle(AppLocalizations l) {
    switch (kind) {
      case _EmptyKind.noTeam:
        return l.emptyNoTeamSubtitle;
      case _EmptyKind.noLeague:
        return l.emptyNoLeagueSubtitle;
      case _EmptyKind.noPlayers:
        return l.emptyNoPlayersSubtitle;
      case _EmptyKind.noNews:
        return l.emptyNoNewsSubtitle;
      case _EmptyKind.noBattles:
        return l.emptyNoBattlesSubtitle;
      case _EmptyKind.noHistory:
        return l.emptyNoHistorySubtitle;
      case _EmptyKind.offline:
        return l.emptyOfflineSubtitle;
      case _EmptyKind.error:
        return errorMsg ?? l.emptyErrorSubtitle;
      case null:
        return null;
    }
  }

  String? _resolveAction(AppLocalizations l) {
    switch (kind) {
      case _EmptyKind.noTeam:
        return l.emptyNoTeamAction;
      case _EmptyKind.noLeague:
        return l.createLeague;
      case _EmptyKind.noPlayers:
        return l.resetFilters;
      case _EmptyKind.noNews:
        return l.refresh;
      case _EmptyKind.offline:
      case _EmptyKind.error:
        return l.retry;
      case _EmptyKind.noBattles:
      case _EmptyKind.noHistory:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    final rTitle = title ?? _resolveTitle(l);
    final rSubtitle = subtitle ?? _resolveSubtitle(l);
    final rAction = actionLabel ?? _resolveAction(l);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône avec halo
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: color.withValues(alpha: 0.8)),
            )
                .animate()
                .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 400.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // Titre
            Text(
              rTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: 100.ms)
                .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: 100.ms),

            if (rSubtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                rSubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 150.ms),
            ],

            if (rAction != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(icon, size: 16),
                label: Text(rAction, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 200.ms)
                  .slideY(begin: 0.2, end: 0, duration: 300.ms, delay: 200.ms),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget d'erreur réseau avec retry
class AppErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState.error(onRetry: onRetry, msg: message);
  }
}
