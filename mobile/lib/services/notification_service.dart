import 'dart:async';

enum NotificationType { info, success, warning, battle, gameweek }

class AppNotification {
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;

  AppNotification({
    required this.title,
    required this.body,
    required this.type,
  }) : timestamp = DateTime.now();
}

/// In-app notification bus — listens to socket events and broadcasts
/// AppNotification objects that the UI overlay can display.
class NotificationService {
  final _controller = StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get stream => _controller.stream;

  void push(AppNotification notification) {
    _controller.add(notification);
  }

  void pushBattleResult({required String homeTeam, required int homeScore,
      required String awayTeam, required int awayScore}) {
    final winner = homeScore > awayScore ? homeTeam : awayTeam;
    push(AppNotification(
      title: 'Battle terminé',
      body: '$homeTeam $homeScore – $awayScore $awayTeam · Vainqueur: $winner',
      type: NotificationType.battle,
    ));
  }

  void pushGameweekStarted(int gwNumber) {
    push(AppNotification(
      title: 'Gameweek $gwNumber démarrée !',
      body: 'Les scores sont en cours de mise à jour en direct.',
      type: NotificationType.gameweek,
    ));
  }

  void pushGameweekFinished(int gwNumber) {
    push(AppNotification(
      title: 'Gameweek $gwNumber terminée',
      body: 'Les points finaux ont été calculés. Consultez votre classement !',
      type: NotificationType.success,
    ));
  }

  void pushScoreUpdate(int count) {
    push(AppNotification(
      title: 'Scores mis à jour',
      body: '$count joueurs ont vu leurs points recalculés.',
      type: NotificationType.info,
    ));
  }

  void dispose() {
    _controller.close();
  }
}

final notificationService = NotificationService();
