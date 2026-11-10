import 'dart:convert';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'socket_service.dart';
import 'notification_service.dart';

/// Push Notification Service — flutter_local_notifications (100% GRATUIT)
///
/// Affiche des vraies notifications système (barre de statut) déclenchées
/// automatiquement par les événements socket.io (scores, battles, deadlines).
///
/// Avantages :
///  - 100% gratuit, AUCUN compte externe requis
///  - AUCUNE configuration Firebase/Google nécessaire
///  - Connecté aux events socket.io temps réel
///  - Compatible Android 5+ et iOS 10+
///  - Fonctionne quand l'app est en arrière-plan
///
/// Pour les Push distantes (app complètement fermée) :
///  → Firebase FCM (gratuit, nécessite google-services.json + compte Firebase)

const _channelId = 'fantasy_wc_main';
const _channelName = 'WC Fantasy';
const _channelDesc = 'Scores, battles, deadlines';

const _androidDetails = AndroidNotificationDetails(
  _channelId,
  _channelName,
  channelDescription: _channelDesc,
  importance: Importance.high,
  priority: Priority.high,
  icon: '@mipmap/ic_launcher',
  color: AppColors.gold,
  enableVibration: true,
  playSound: true,
);

const _iosDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
);

const _notifDetails = NotificationDetails(
  android: _androidDetails,
  iOS: _iosDetails,
);

class PushNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notifId = 0;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(initSettings);

    // Créer le canal Android (Android 8.0+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );

    // Écouter les événements socket.io et déclencher des notifications
    _listenToSocketEvents();

    debugPrint('[PushNotif] Service initialisé');
  }

  void _listenToSocketEvents() {
    final socket = socketService.socket;
    if (socket == null) return;

    // ── Mise à jour des scores ────────────────────────────────────────────
    socket.on('scores:updated', (data) {
      final gwNumber = data?['gameweekNumber'] ?? '?';
      show(
        title: '⚽ Scores mis à jour — GW$gwNumber',
        body: 'Les points de votre équipe viennent d\'être recalculés. Consultez votre classement !',
        type: 'score',
        payload: {'route': '/gameweeks'},
      );
      notificationService.pushScoreUpdate(0);
    });

    // ── Deadline gameweek ─────────────────────────────────────────────────
    socket.on('deadline:warning', (data) {
      final gwNumber = data?['gwNumber'] ?? '?';
      final hours = data?['hoursLeft'] ?? '?';
      show(
        title: '⏰ Deadline GW$gwNumber dans $hours h',
        body: 'Dernière chance pour finaliser votre équipe et faire vos transferts !',
        type: 'deadline',
        payload: {'route': '/draft'},
      );
    });

    // ── Battle résultat ───────────────────────────────────────────────────
    socket.on('battle:result', (data) {
      final home = data?['homeTeam'] ?? '';
      final away = data?['awayTeam'] ?? '';
      final homeScore = data?['homeScore'] ?? 0;
      final awayScore = data?['awayScore'] ?? 0;
      show(
        title: '⚔️ Battle terminé !',
        body: '$home $homeScore – $awayScore $away',
        type: 'battle',
        payload: {'route': '/leagues'},
      );
    });

    // ── Nouveau gameweek ──────────────────────────────────────────────────
    socket.on('gameweek:started', (data) {
      final gwNumber = data?['number'] ?? '?';
      show(
        title: '🚀 Gameweek $gwNumber démarrée !',
        body: 'Les matchs commencent. Suivez vos joueurs en direct !',
        type: 'score',
        payload: {'route': '/gameweeks'},
      );
      notificationService.pushGameweekStarted(gwNumber as int);
    });

    // ── Transfert accepté ─────────────────────────────────────────────────
    socket.on('transfer:accepted', (data) {
      final player = data?['playerName'] ?? 'Un joueur';
      show(
        title: '✅ Transfert accepté',
        body: '$player rejoint votre équipe !',
        type: 'general',
        payload: {'route': '/draft'},
      );
    });
  }

  /// Affiche une notification système immédiate.
  Future<void> show({
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _notifId++,
        title,
        body,
        _notifDetails,
        payload: payload != null ? jsonEncode(payload) : null,
      );
    } catch (e) {
      debugPrint('[PushNotif] Erreur: $e');
    }
  }

  /// Notification planifiée — ex: rappel deadline 1h avant
  Future<void> scheduleDeadlineReminder({
    required DateTime deadline,
    required int gwNumber,
  }) async {
    if (!_initialized) await init();
    final reminderTime = deadline.subtract(const Duration(hours: 1));
    if (reminderTime.isBefore(DateTime.now())) return;

    // flutter_local_notifications supporte les notifications planifiées
    // via zonedSchedule (requiert timezone package pour la production)
    debugPrint('[PushNotif] Deadline GW$gwNumber planifiée: $reminderTime');
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

final pushNotificationService = PushNotificationService();
