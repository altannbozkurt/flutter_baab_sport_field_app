// lib/features/lobby/providers/lobby_notifier_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:flutter_baab_sport_field_app/features/lobby/repositories/lobby_repository.dart';
import 'package:flutter_baab_sport_field_app/models/lobby_posting.dart';
import 'package:flutter_baab_sport_field_app/features/lobby/providers/lobby_provider.dart';

// Formun durumunu (state) yönetmek için bir class
class LobbyFormState {
  final bool isLoading;
  final String? error;
  final LobbyPosting? successPost;

  LobbyFormState({this.isLoading = false, this.error, this.successPost});

  LobbyFormState copyWith({
    bool? isLoading,
    String? error,
    LobbyPosting? successPost,
  }) {
    return LobbyFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successPost: successPost,
    );
  }
}

// StateNotifier
class LobbyNotifier extends StateNotifier<LobbyFormState> {
  final LobbyRepository _lobbyRepository;
  final Ref _ref;

  LobbyNotifier(this._lobbyRepository, this._ref) : super(LobbyFormState());

  Future<bool> createPost({
    required String title,
    required String? description,
    required String type,
    required String? fieldId,
    required DateTime matchTime,
    required int teamSize,
    required int? playersNeeded,
    required String? positionNeeded,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successPost: null);
    try {
      final newPost = await _lobbyRepository.createPost(
        title: title,
        description: description,
        type: type,
        fieldId: fieldId,
        matchTime: matchTime,
        teamSize: teamSize,
        playersNeeded: playersNeeded,
        positionNeeded: positionNeeded,
      );

      state = state.copyWith(isLoading: false, successPost: newPost);
      // Lobi listesini (GET /lobby) yenile
      _ref.invalidate(openLobbyPostsProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

// StateNotifierProvider
final lobbyNotifierProvider =
    StateNotifierProvider<LobbyNotifier, LobbyFormState>((ref) {
      final lobbyRepository = ref.watch(lobbyRepositoryProvider);
      return LobbyNotifier(lobbyRepository, ref);
    });
