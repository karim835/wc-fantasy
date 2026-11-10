import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/league.dart';
import '../services/api_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class LeagueState {
  final List<League> leagues;
  final League? selectedLeague;
  final List<LeaderboardEntry> leaderboard;
  final bool isLoading;
  final String? error;

  const LeagueState({
    this.leagues = const [],
    this.selectedLeague,
    this.leaderboard = const [],
    this.isLoading = false,
    this.error,
  });

  LeagueState copyWith({
    List<League>? leagues,
    League? selectedLeague,
    List<LeaderboardEntry>? leaderboard,
    bool? isLoading,
    String? error,
  }) =>
      LeagueState(
        leagues: leagues ?? this.leagues,
        selectedLeague: selectedLeague ?? this.selectedLeague,
        leaderboard: leaderboard ?? this.leaderboard,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class LeagueNotifier extends StateNotifier<LeagueState> {
  LeagueNotifier() : super(const LeagueState());

  Future<void> loadLeagues() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.getLeagues();
      final leagues = data
          .map((l) => League.fromJson(l as Map<String, dynamic>))
          .toList();
      state = state.copyWith(leagues: leagues, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<League?> createLeague({
    required String name,
    int maxMembers = 10,
    bool isPrivate = false,
    String? season,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.createLeague(
        name: name,
        maxMembers: maxMembers,
        isPrivate: isPrivate,
        season: season,
      );
      final league = League.fromJson(data);
      state = state.copyWith(
        leagues: [...state.leagues, league],
        isLoading: false,
      );
      return league;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> joinLeague(String inviteCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await apiService.joinLeague(inviteCode);
      await loadLeagues();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> selectLeague(String leagueId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.getLeague(leagueId);
      final league = League.fromJson(data);
      state = state.copyWith(selectedLeague: league, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadLeaderboard(String leagueId) async {
    try {
      final data = await apiService.getLeaderboard(leagueId);
      final entries = data
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(leaderboard: entries);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('404')) return 'Code d\'invitation invalide';
    if (msg.contains('400') && msg.contains('full')) return 'La ligue est complète';
    return 'Erreur lors de l\'opération';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final leagueProvider = StateNotifierProvider<LeagueNotifier, LeagueState>(
  (ref) => LeagueNotifier(),
);
