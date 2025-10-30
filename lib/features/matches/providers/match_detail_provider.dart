// lib/features/matches/providers/match_detail_provider.dart
import 'package:flutter_baab_sport_field_app/features/matches/repositories/match_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/models/match.dart';

// FutureProvider.family, provider'a dışarıdan bir parametre (matchId)
// göndermemizi sağlar.
final matchDetailProvider = FutureProvider.autoDispose.family<Match, String>((
  ref,
  matchId,
) async {
  // MatchRepository'yi oku
  final matchRepository = ref.watch(matchRepositoryProvider);
  // Repository'deki fonksiyonu çağır ve sonucu (Future) döndür
  return matchRepository.getMatchDetails(matchId);
});
