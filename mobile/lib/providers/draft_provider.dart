import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/team.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class DraftState {
  final Team? team;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? autoPickSuggestion;

  const DraftState({
    this.team,
    this.isLoading = false,
    this.error,
    this.autoPickSuggestion,
  });

  DraftState copyWith({
    Team? team,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? autoPickSuggestion,
  }) =>
      DraftState(
        team: team ?? this.team,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        autoPickSuggestion: autoPickSuggestion ?? this.autoPickSuggestion,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class DraftNotifier extends StateNotifier<DraftState> {
  DraftNotifier() : super(const DraftState());

  Future<void> loadTeam(String leagueId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.getMyTeam(leagueId);
      final team = Team.fromJson(data);
      state = state.copyWith(team: team, isLoading: false);
    } catch (e) {
      // Team may not exist yet
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> createTeam(String leagueId, String name, String formation) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.createTeam(leagueId, name, formation);
      final team = Team.fromJson(data);
      state = state.copyWith(team: team, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> pickPlayer(String leagueId, String playerId, String playerName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.pickPlayer(leagueId, playerId);
      final team = Team.fromJson(data);
      state = state.copyWith(team: team, isLoading: false);
      // Broadcast via socket
      socketService.emitDraftPick(leagueId, playerId, playerName);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> removePlayer(String leagueId, String playerId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.removePlayer(leagueId, playerId);
      final team = Team.fromJson(data);
      state = state.copyWith(team: team, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> autoPickSuggestion(String leagueId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.autoPick(leagueId);
      final suggestion = data['suggestion'] as Map<String, dynamic>?;
      state = state.copyWith(autoPickSuggestion: suggestion, isLoading: false);
      return suggestion;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('full')) return 'Équipe complète (max 15 joueurs)';
    if (msg.contains('budget')) return 'Budget insuffisant';
    if (msg.contains('already')) return 'Joueur déjà dans l\'équipe';
    return 'Erreur lors du draft';
  }
}

// ── Remove player from api_service.dart ──────────────────────────────────────
// Providers
final draftProvider = StateNotifierProvider.family<DraftNotifier, DraftState, String>(
  (ref, leagueId) => DraftNotifier()..loadTeam(leagueId),
);
