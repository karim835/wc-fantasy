import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'notification_service.dart';

typedef EventCallback = void Function(dynamic data);

class SocketService {
  // Derive base URL from API_URL by stripping trailing /api — only one --dart-define needed
  static final String _serverUrl = const String.fromEnvironment(
    'API_URL', defaultValue: 'http://localhost:3000/api',
  ).replaceAll(RegExp(r'/api$'), '');
  static const _storage = FlutterSecureStorage();

  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  Future<void> connect() async {
    if (_isConnected) return;

    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('No access token found');

    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('[Socket] connected: ${_socket!.id}');
    });

    // Global notifications wired to socket events
    _socket!.on('gameweek:started', (data) {
      final gw = data as Map<String, dynamic>?;
      final num = gw?['number'] ?? '?';
      notificationService.pushGameweekStarted(num is int ? num : int.tryParse('$num') ?? 0);
    });

    _socket!.on('gameweek:finished', (data) {
      final gw = data as Map<String, dynamic>?;
      final num = gw?['number'] ?? '?';
      notificationService.pushGameweekFinished(num is int ? num : int.tryParse('$num') ?? 0);
    });

    _socket!.on('gameweek:points_updated', (data) {
      // silent — screens refresh themselves
    });

    _socket!.on('battle:score_update', (data) {
      final b = data as Map<String, dynamic>?;
      if (b != null && b['status'] == 'completed') {
        notificationService.pushBattleResult(
          homeTeam: b['home_team_name'] as String? ?? 'Home',
          homeScore: (b['home_score'] as num?)?.toInt() ?? 0,
          awayTeam: b['away_team_name'] as String? ?? 'Away',
          awayScore: (b['away_score'] as num?)?.toInt() ?? 0,
        );
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('[Socket] disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('[Socket] connection error: $err');
    });

    _socket!.onError((err) {
      debugPrint('[Socket] error: $err');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  // League rooms
  void joinLeague(String leagueId) {
    _socket?.emit('league:join', leagueId);
  }

  void leaveLeague(String leagueId) {
    _socket?.emit('league:leave', leagueId);
  }

  // Battle watching
  void watchBattle(String battleId) {
    _socket?.emit('battle:watch', battleId);
  }

  void unwatchBattle(String battleId) {
    _socket?.emit('battle:unwatch', battleId);
  }

  // Draft pick event
  void emitDraftPick(String leagueId, String playerId, String playerName) {
    _socket?.emit('draft:pick', {
      'leagueId': leagueId,
      'playerId': playerId,
      'playerName': playerName,
    });
  }

  // Chat
  void sendChatMessage(String leagueId, String message) {
    _socket?.emit('chat:message', {'leagueId': leagueId, 'message': message});
  }

  // Event listeners
  void onBattleScoreUpdate(EventCallback callback) {
    _socket?.on('battle:score_update', callback);
  }

  void onBattleScheduled(EventCallback callback) {
    _socket?.on('battle:scheduled', callback);
  }

  void onDraftPlayerPicked(EventCallback callback) {
    _socket?.on('draft:player_picked', callback);
  }

  void onChatMessage(EventCallback callback) {
    _socket?.on('chat:new_message', callback);
  }

  void onLeagueUserJoined(EventCallback callback) {
    _socket?.on('league:user_joined', callback);
  }

  void on(String event, EventCallback callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  /// Generic emit for ad-hoc events (e.g. chat:typing).
  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }
}

final socketService = SocketService();
