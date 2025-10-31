// lib/features/lobby/providers/lobby_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/models/lobby_posting.dart';
import 'package:flutter_baab_sport_field_app/features/lobby/repositories/lobby_repository.dart';

// Bu FutureProvider, lobideki açık ilanları getirir ve cache'ler
final openLobbyPostsProvider = FutureProvider<List<LobbyPosting>>((ref) async {
  // lobbyRepositoryProvider'ı izle
  final lobbyRepository = ref.watch(lobbyRepositoryProvider);
  // Repository'den ilanları iste
  return lobbyRepository.getOpenPosts();
});
