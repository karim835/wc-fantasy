import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // For web (Chrome): use localhost. For physical device: use WiFi IP (run update-ip.ps1)
  static const String _baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000/api');
  static const _storage = FlutterSecureStorage();

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      // Timeouts intentionally disabled (null = infinite) — requests wait
      // indefinitely instead of throwing "timeout exceeded". A stuck request
      // will spin rather than error; the real fix for hangs is the connection
      // (backend running + `adb reverse tcp:3000 tcp:3000` on USB).
      connectTimeout: null,
      receiveTimeout: null,
      sendTimeout: null,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 &&
            !e.requestOptions.path.contains('/auth/refresh') &&
            !e.requestOptions.path.contains('/auth/login')) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            e.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (retryErr) {
              return handler.next(e);
            }
          }
          // Refresh failed — session expired, caller should redirect to login
          return handler.next(DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: DioExceptionType.badResponse,
            error: 'SESSION_EXPIRED',
          ));
        }
        handler.next(e);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        await _clearSession();
        return false;
      }

      final response = await Dio(BaseOptions(baseUrl: _baseUrl))
          .post('/auth/refresh', data: {'refreshToken': refreshToken});
      await _storage.write(key: 'access_token', value: response.data['accessToken']);
      await _storage.write(key: 'refresh_token', value: response.data['refreshToken']);
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  Future<void> _clearSession() async {
    await _storage.deleteAll();
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    await _storage.write(key: 'access_token', value: res.data['accessToken']);
    await _storage.write(key: 'refresh_token', value: res.data['refreshToken']);
    return res.data;
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password, {
    String? dateOfBirth,
    String? country,
    String? favoriteNation,
    String? favoriteClub,
    String? favoritePlayer,
    String? bio,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (country != null) 'country': country,
      if (favoriteNation != null) 'favorite_nation': favoriteNation,
      if (favoriteClub != null) 'favorite_club': favoriteClub,
      if (favoritePlayer != null) 'favorite_player': favoritePlayer,
      if (bio != null) 'bio': bio,
    });
    await _storage.write(key: 'access_token', value: res.data['accessToken']);
    await _storage.write(key: 'refresh_token', value: res.data['refreshToken']);
    return res.data;
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    try {
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
    await _clearSession();
  }

  /// True if an access token is stored — used by the splash screen to decide
  /// whether to route to /home (offline-friendly) or /login on launch.
  Future<bool> hasSession() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get('/auth/profile');
    return res.data;
  }

  Future<Map<String, dynamic>> getProfileStats() async {
    final res = await _dio.get('/auth/profile/stats');
    return res.data;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? email,
    String? avatarUrl,
    String? dateOfBirth,
    String? country,
    String? favoriteNation,
    String? favoriteClub,
    String? favoritePlayer,
    String? bio,
  }) async {
    final res = await _dio.patch('/auth/profile', data: {
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (country != null) 'country': country,
      if (favoriteNation != null) 'favorite_nation': favoriteNation,
      if (favoriteClub != null) 'favorite_club': favoriteClub,
      if (favoritePlayer != null) 'favorite_player': favoritePlayer,
      if (bio != null) 'bio': bio,
    });
    return res.data;
  }

  /// Upload a profile photo (base64). Returns the new relative avatar_url.
  Future<String?> uploadAvatar(List<int> bytes, String ext) async {
    final res = await _dio.post('/auth/avatar', data: {
      'image': base64Encode(bytes),
      'ext': ext,
    });
    return res.data?['avatar_url'] as String?;
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/auth/account');
    await _clearSession();
  }

  /// Resolve a server-relative path (e.g. "/api/photos/avatar/<id>") to an
  /// absolute URL using the API host. Pass-through for already-absolute URLs.
  static String absoluteUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    final origin = _baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$origin$pathOrUrl';
  }

  // Leagues
  Future<List<dynamic>> getLeagues() async {
    final res = await _dio.get('/leagues');
    return res.data;
  }

  Future<Map<String, dynamic>> createLeague({
    required String name,
    int maxMembers = 10,
    bool isPrivate = false,
    String? season,
  }) async {
    final res = await _dio.post('/leagues', data: {
      'name': name,
      'max_members': maxMembers,
      'is_private': isPrivate,
      'season': season,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getLeague(String leagueId) async {
    final res = await _dio.get('/leagues/$leagueId');
    return res.data;
  }

  Future<void> joinLeague(String inviteCode) async {
    // Backend attend snake_case: invite_code
    await _dio.post('/leagues/join', data: {'invite_code': inviteCode});
  }

  Future<List<dynamic>> getLeaderboard(String leagueId) async {
    final res = await _dio.get('/leagues/$leagueId/leaderboard');
    return res.data;
  }

  // Leagues — membership, owner controls, discovery (Round 6)
  Future<List<dynamic>> getPublicLeagues() async {
    final res = await _dio.get('/leagues/public');
    return res.data as List<dynamic>;
  }

  Future<void> joinPublicLeague(String leagueId) async {
    await _dio.post('/leagues/$leagueId/join-public');
  }

  Future<void> leaveLeague(String leagueId) async {
    await _dio.delete('/leagues/$leagueId/leave');
  }

  Future<void> updateLeague(String leagueId, {String? name, int? maxMembers, bool? isPrivate}) async {
    await _dio.patch('/leagues/$leagueId', data: {
      if (name != null) 'name': name,
      if (maxMembers != null) 'max_members': maxMembers,
      if (isPrivate != null) 'is_private': isPrivate,
    });
  }

  Future<void> deleteLeague(String leagueId) async {
    await _dio.delete('/leagues/$leagueId');
  }

  Future<void> kickMember(String leagueId, String userId) async {
    await _dio.delete('/leagues/$leagueId/members/$userId');
  }

  Future<Map<String, dynamic>> getMemberTeam(String leagueId, String userId) async {
    final res = await _dio.get('/leagues/$leagueId/members/$userId/team');
    return res.data as Map<String, dynamic>;
  }

  // Users — public profile (Round 6)
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final res = await _dio.get('/users/$userId/profile');
    return res.data as Map<String, dynamic>;
  }

  // Draft / Team
  Future<Map<String, dynamic>> getMyTeam(String leagueId) async {
    final res = await _dio.get('/drafts/leagues/$leagueId/team');
    return res.data;
  }

  Future<Map<String, dynamic>> createTeam(String leagueId, String name, String formation) async {
    final res = await _dio.post('/drafts/leagues/$leagueId/team', data: {
      'name': name,
      'formation': formation,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> pickPlayer(String leagueId, String playerId) async {
    final res = await _dio.post('/drafts/leagues/$leagueId/team/pick', data: {'playerId': playerId});
    return res.data;
  }

  Future<Map<String, dynamic>> removePlayer(String leagueId, String playerId) async {
    final res = await _dio.delete('/drafts/leagues/$leagueId/team/players/$playerId');
    return res.data;
  }

  Future<Map<String, dynamic>> updateTeam(String leagueId, {String? name, String? formation}) async {
    final res = await _dio.patch('/drafts/leagues/$leagueId/team', data: {
      if (name != null) 'name': name,
      if (formation != null) 'formation': formation,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clearTeamPlayers(String leagueId) async {
    final res = await _dio.delete('/drafts/leagues/$leagueId/team/players');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> autoPick(String leagueId, {Map<String, dynamic>? preferences}) async {
    final res = await _dio.post('/drafts/leagues/$leagueId/team/auto-pick', data: {
      if (preferences != null) 'preferences': preferences,
    });
    return res.data;
  }

  // Players
  Future<Map<String, dynamic>> getPlayers({
    String? position,
    String? search,
    String? nationality,
    String? sort,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get('/players', queryParameters: {
      if (position != null) 'position': position,
      if (search != null) 'search': search,
      if (nationality != null) 'nationality': nationality,
      if (sort != null) 'sort': sort,
      'page': page,
      'limit': limit,
    });
    return res.data;
  }

  Future<List<dynamic>> getTopPlayers({String? position, int limit = 10}) async {
    final res = await _dio.get('/players/top', queryParameters: {
      if (position != null) 'position': position,
      'limit': limit,
    });
    return res.data;
  }

  /// Distinct nationalities present in the players table, with counts:
  /// `[{nationality, count}]`. Drives the Nations screen.
  Future<List<dynamic>> getNationalities() async {
    final res = await _dio.get('/players/nationalities');
    return res.data;
  }

  // Gameweeks
  Future<List<dynamic>> getGameweeks() async {
    final res = await _dio.get('/gameweeks');
    return res.data;
  }

  Future<Map<String, dynamic>?> getCurrentGameweek() async {
    try {
      final res = await _dio.get('/gameweeks/current');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getGameweekTeamScores(String gameweekId) async {
    final res = await _dio.get('/gameweeks/$gameweekId/team-scores');
    return res.data;
  }

  Future<List<dynamic>> getGameweekPlayerScores(String gameweekId) async {
    final res = await _dio.get('/gameweeks/$gameweekId/scores');
    return res.data;
  }

  Future<Map<String, dynamic>> getGameweekBreakdown(String gameweekId, {String? leagueId}) async {
    final res = await _dio.get('/gameweeks/$gameweekId/my-breakdown', queryParameters: {
      if (leagueId != null) 'leagueId': leagueId,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Admin dashboard ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> adminOverview() async {
    final res = await _dio.get('/admin/overview');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminUsers({String? search, int limit = 50, int offset = 0}) async {
    final res = await _dio.get('/admin/users', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': limit,
      'offset': offset,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> adminSetUserRole(String userId, String role) async {
    await _dio.patch('/admin/users/$userId/role', data: {'role': role});
  }

  Future<void> adminDeleteUser(String userId) async {
    await _dio.delete('/admin/users/$userId');
  }

  Future<List<dynamic>> adminLeagues({String? search}) async {
    final res = await _dio.get('/admin/leagues', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as Map<String, dynamic>)['leagues'] as List<dynamic>;
  }

  Future<void> adminDeleteLeague(String leagueId) async {
    await _dio.delete('/admin/leagues/$leagueId');
  }

  Future<Map<String, dynamic>> adminUpdatePlayer(String playerId, Map<String, dynamic> fields) async {
    final res = await _dio.patch('/admin/players/$playerId', data: fields);
    return (res.data as Map<String, dynamic>)['player'] as Map<String, dynamic>;
  }

  // Matches / fixtures
  Future<List<dynamic>> getMatches({String? status, int? matchday}) async {
    final res = await _dio.get('/matches', queryParameters: {
      if (status != null) 'status': status,
      if (matchday != null) 'matchday': matchday,
    });
    return res.data as List<dynamic>;
  }

  // Chips / boosts
  Future<Map<String, dynamic>> armChip(String leagueId, String chip, {String? boostPlayerId}) async {
    final res = await _dio.patch('/drafts/leagues/$leagueId/team/chip', data: {
      'chip': chip,
      if (boostPlayerId != null) 'boostPlayerId': boostPlayerId,
    });
    return res.data as Map<String, dynamic>;
  }

  // Friends
  Future<List<dynamic>> getFriends() async {
    final res = await _dio.get('/friends');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getFriendRequests() async {
    final res = await _dio.get('/friends/requests');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> searchUsers(String q) async {
    final res = await _dio.get('/friends/search', queryParameters: {'q': q});
    return res.data as List<dynamic>;
  }

  Future<void> sendFriendRequest(String username) async {
    await _dio.post('/friends/request', data: {'username': username});
  }

  Future<void> acceptFriend(String userId) async {
    await _dio.post('/friends/$userId/accept');
  }

  Future<void> removeFriend(String userId) async {
    await _dio.delete('/friends/$userId');
  }

  // News
  Future<Map<String, dynamic>> getNews({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    final res = await _dio.get('/news', queryParameters: {
      'page': page,
      'limit': limit,
      if (category != null) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getLatestHeadlines() async {
    final res = await _dio.get('/news/latest');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getNewsCategories() async {
    final res = await _dio.get('/news/categories');
    return res.data as List<dynamic>;
  }

  // Captain
  Future<Map<String, dynamic>> setCaptain(String leagueId, String playerId) async {
    final res = await _dio.patch('/drafts/leagues/$leagueId/team/captain', data: {'playerId': playerId});
    return res.data as Map<String, dynamic>;
  }

  // Predictions
  Future<Map<String, dynamic>> submitPrediction({
    required String gameweekId,
    String? predictedTopScorer,
    String? predictedWinnerNation,
    int? predictedGoals,
  }) async {
    final res = await _dio.post('/predictions', data: {
      'gameweekId': gameweekId,
      if (predictedTopScorer != null) 'predictedTopScorer': predictedTopScorer,
      if (predictedWinnerNation != null) 'predictedWinnerNation': predictedWinnerNation,
      if (predictedGoals != null) 'predictedGoals': predictedGoals,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGameweekPredictions(String gwId) async {
    final res = await _dio.get('/predictions/gameweek/$gwId');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPredictionLeaderboard() async {
    final res = await _dio.get('/predictions/leaderboard');
    return res.data as List<dynamic>;
  }

  // Battles
  Future<List<dynamic>> getBattles(String leagueId) async {
    final res = await _dio.get('/battles/leagues/$leagueId/battles');
    return res.data;
  }

  Future<Map<String, dynamic>> getBattle(String battleId) async {
    final res = await _dio.get('/battles/battles/$battleId');
    return res.data;
  }

  Future<Map<String, dynamic>> getLiveScore(String battleId) async {
    final res = await _dio.get('/battles/battles/$battleId/live');
    return res.data;
  }

  // Transfers
  Future<Map<String, dynamic>> getTransferSuggestions(String leagueId) async {
    final res = await _dio.get('/transfers/leagues/$leagueId/suggestions');
    return res.data;
  }

  Future<Map<String, dynamic>> getRiskScore(String playerId) async {
    final res = await _dio.get('/transfers/players/$playerId/risk');
    return res.data;
  }

  Future<Map<String, dynamic>> makeTransfer(
    String leagueId,
    String playerOutId,
    String playerInId,
  ) async {
    final res = await _dio.post('/transfers/leagues/$leagueId/transfer', data: {
      'playerOutId': playerOutId,
      'playerInId': playerInId,
    });
    return res.data;
  }

  // Settings
  Future<Map<String, dynamic>> getSettings() async {
    final res = await _dio.get('/auth/settings');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    final res = await _dio.patch('/auth/settings', data: settings);
    return res.data as Map<String, dynamic>;
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.patch('/auth/profile/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<List<dynamic>> getAchievements() async {
    final res = await _dio.get('/auth/achievements');
    return res.data['achievements'] as List<dynamic>;
  }

  // Gameweek admin
  Future<Map<String, dynamic>> createGameweek({
    required int number,
    required String deadline,
    String season = '2025-26',
  }) async {
    final res = await _dio.post('/gameweeks', data: {
      'number': number,
      'deadline': deadline,
      'season': season,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startGameweek(String gwId) async {
    final res = await _dio.patch('/gameweeks/$gwId/start');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> finishGameweek(String gwId) async {
    final res = await _dio.patch('/gameweeks/$gwId/finish');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitPlayerScores(
    String gwId,
    String playerId,
    Map<String, dynamic> stats,
  ) async {
    final res = await _dio.post('/gameweeks/$gwId/scores', data: {
      'playerId': playerId,
      ...stats,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateBattles(String gwId, String leagueId) async {
    final res = await _dio.post('/gameweeks/generate-battles', data: {
      'gwId': gwId,
      'leagueId': leagueId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scheduleBattle(
    String leagueId,
    String homeTeamId,
    String awayTeamId,
    String gwId,
  ) async {
    final res = await _dio.post('/battles/leagues/$leagueId/battles', data: {
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'gameweek': gwId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBattleScore(
    String battleId, {
    required int homeScore,
    required int awayScore,
  }) async {
    final res = await _dio.patch('/battles/battles/$battleId/score', data: {
      'homeScore': homeScore,
      'awayScore': awayScore,
    });
    return res.data as Map<String, dynamic>;
  }

  // Challenges
  Future<Map<String, dynamic>> getChallenges() async {
    final res = await _dio.get('/challenges');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeChallenge(String challengeKey) async {
    final res = await _dio.post('/challenges/complete', data: {'challengeKey': challengeKey});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getChallengeLeaderboard() async {
    final res = await _dio.get('/challenges/leaderboard');
    return res.data as List<dynamic>;
  }

  // Chat
  Future<List<dynamic>> getChatMessages(String leagueId) async {
    final res = await _dio.get('/chat/leagues/$leagueId/messages');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendChatMessage(String leagueId, String message) async {
    final res = await _dio.post('/chat/leagues/$leagueId/messages', data: {'message': message});
    return res.data as Map<String, dynamic>;
  }

  // Chatbot (Gemini AI)
  Future<String> sendChatbotMessage(String message, List<Map<String, String>> history) async {
    final res = await _dio.post('/chatbot/chat', data: {
      'message': message,
      'history': history,
    });
    return res.data['reply'] as String? ?? 'Sorry, I could not generate a response.';
  }

  // ── Méthodes génériques pour les écrans admin ──────────────────────────────
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, [dynamic data]) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, [dynamic data]) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return _dio.delete(path);
  }
}

final apiService = ApiService();
