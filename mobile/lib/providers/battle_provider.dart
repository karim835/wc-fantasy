import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/battle.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class BattleState {
  final List<Battle> battles;
  final Battle? selectedBattle;
  final Map<String, dynamic>? liveScore;
  final bool isLoading;
  final String? error;

  const BattleState({
    this.battles = const [],
    this.selectedBattle,
    this.liveScore,
    this.isLoading = false,
    this.error,
  });

  BattleState copyWith({
    List<Battle>? battles,
    Battle? selectedBattle,
    Map<String, dynamic>? liveScore,
    bool? isLoading,
    String? error,
  }) =>
      BattleState(
        battles: battles ?? this.battles,
        selectedBattle: selectedBattle ?? this.selectedBattle,
        liveScore: liveScore ?? this.liveScore,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class BattleNotifier extends StateNotifier<BattleState> {
  BattleNotifier() : super(const BattleState());

  Future<void> loadBattles(String leagueId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.getBattles(leagueId);
      final battles = data
          .map((b) => Battle.fromJson(b as Map<String, dynamic>))
          .toList();
      state = state.copyWith(battles: battles, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadBattle(String battleId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.getBattle(battleId);
      final battle = Battle.fromJson(data);
      state = state.copyWith(selectedBattle: battle, isLoading: false);

      // Start watching for live updates
      socketService.watchBattle(battleId);
      socketService.onBattleScoreUpdate((update) {
        if (mounted) {
          state = state.copyWith(liveScore: update as Map<String, dynamic>);
        }
      });
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refreshLiveScore(String battleId) async {
    try {
      final data = await apiService.getLiveScore(battleId);
      state = state.copyWith(liveScore: data);
    } catch (_) {}
  }

  void stopWatching(String battleId) {
    socketService.unwatchBattle(battleId);
    socketService.off('battle:score_update');
  }
}

// Providers
final battleProvider = StateNotifierProvider<BattleNotifier, BattleState>(
  (ref) => BattleNotifier(),
);

final leagueBattlesProvider = FutureProvider.family<List<Battle>, String>((ref, leagueId) async {
  final data = await apiService.getBattles(leagueId);
  return data
      .map((b) => Battle.fromJson(b as Map<String, dynamic>))
      .toList();
});
