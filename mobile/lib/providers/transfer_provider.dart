import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer.dart';
import '../services/api_service.dart';

class TransferState {
  final List<TransferSuggestion> suggestions;
  final RiskScore? riskScore;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const TransferState({
    this.suggestions = const [],
    this.riskScore,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  TransferState copyWith({
    List<TransferSuggestion>? suggestions,
    RiskScore? riskScore,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) =>
      TransferState(
        suggestions: suggestions ?? this.suggestions,
        riskScore: riskScore ?? this.riskScore,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        successMessage: successMessage,
      );
}

class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier() : super(const TransferState());

  Future<void> loadSuggestions(String leagueId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.getTransferSuggestions(leagueId);
      final suggestions = ((data['suggestions'] as List<dynamic>?) ?? [])
          .map((s) => TransferSuggestion.fromJson(s as Map<String, dynamic>))
          .toList();
      state = state.copyWith(suggestions: suggestions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> checkRisk(String playerId) async {
    state = state.copyWith(isLoading: true, error: null, riskScore: null);
    try {
      final data = await apiService.getRiskScore(playerId);
      final risk = RiskScore.fromJson(data);
      state = state.copyWith(riskScore: risk, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> makeTransfer(
    String leagueId,
    String playerOutId,
    String playerInId,
  ) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      await apiService.makeTransfer(leagueId, playerOutId, playerInId);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Transfert effectué avec succès !',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('budget')) return 'Budget insuffisant pour ce transfert';
    if (msg.contains('not in team')) return 'Ce joueur n\'est pas dans votre équipe';
    return 'Erreur lors du transfert';
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, TransferState>(
  (ref) => TransferNotifier(),
);
