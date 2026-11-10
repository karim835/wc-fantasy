import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../services/api_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class PlayerState {
  final List<Player> players;
  final List<Player> topPlayers;
  final bool isLoading;
  final String? error;
  final int total;
  final int page;
  final String? selectedPosition;
  final String? searchQuery;

  const PlayerState({
    this.players = const [],
    this.topPlayers = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.page = 1,
    this.selectedPosition,
    this.searchQuery,
  });

  PlayerState copyWith({
    List<Player>? players,
    List<Player>? topPlayers,
    bool? isLoading,
    String? error,
    int? total,
    int? page,
    String? selectedPosition,
    String? searchQuery,
  }) =>
      PlayerState(
        players: players ?? this.players,
        topPlayers: topPlayers ?? this.topPlayers,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        total: total ?? this.total,
        page: page ?? this.page,
        selectedPosition: selectedPosition ?? this.selectedPosition,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  bool get hasMore => players.length < total;
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(const PlayerState());

  Future<void> loadPlayers({
    String? position,
    String? search,
    bool reset = false,
  }) async {
    if (reset) {
      state = state.copyWith(players: [], page: 1, error: null);
    }

    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final pos = position == 'All' ? null : position;
      final data = await apiService.getPlayers(
        position: pos,
        search: search?.isEmpty == true ? null : search,
        page: state.page,
      );

      final newPlayers = (data['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        players: reset ? newPlayers : [...state.players, ...newPlayers],
        total: (data['total'] as num?)?.toInt() ?? 0,
        page: state.page + 1,
        isLoading: false,
        selectedPosition: position ?? state.selectedPosition,
        searchQuery: search ?? state.searchQuery,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadTopPlayers({String? position, int limit = 10}) async {
    try {
      final data = await apiService.getTopPlayers(position: position, limit: limit);
      final players = data
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList();
      state = state.copyWith(topPlayers: players);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> filterByPosition(String position) async {
    await loadPlayers(position: position, reset: true);
  }

  Future<void> search(String query) async {
    await loadPlayers(search: query, reset: true);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(),
);

final topPlayersProvider = FutureProvider<List<Player>>((ref) async {
  final data = await apiService.getTopPlayers(limit: 10);
  return data
      .map((p) => Player.fromJson(p as Map<String, dynamic>))
      .toList();
});
