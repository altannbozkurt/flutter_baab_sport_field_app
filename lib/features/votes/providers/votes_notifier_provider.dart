// lib/features/votes/providers/votes_notifier_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart'; // Position için
import 'package:flutter_baab_sport_field_app/features/votes/repositories/votes_repository.dart';
import 'package:flutter_baab_sport_field_app/core/providers/location_provider.dart'; // Konumu almak için
import 'package:meta/meta.dart';

// Oylama işleminin durumunu tutacak state
@immutable
class VotesState {
  final bool isSubmitting; // MVP veya Etiket gönderiliyor
  final String? errorMessage;
  // Kullanıcının bu oturumda oy kullanıp kullanmadığını takip eden bayraklar
  final bool hasVotedMvp;
  final bool hasVotedTag;

  const VotesState({
    this.isSubmitting = false,
    this.errorMessage,
    this.hasVotedMvp = false,
    this.hasVotedTag = false,
  });

  VotesState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? hasVotedMvp,
    bool? hasVotedTag,
  }) {
    return VotesState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasVotedMvp: hasVotedMvp ?? this.hasVotedMvp,
      hasVotedTag: hasVotedTag ?? this.hasVotedTag,
    );
  }
}

// Oylamayı yönetecek Notifier
class VotesNotifier extends StateNotifier<VotesState> {
  final VotesRepository _votesRepository;
  final Ref _ref; // Konumu okumak için

  VotesNotifier(this._votesRepository, this._ref) : super(const VotesState());

  // MVP Oyu Gönderme Metodu
  Future<bool> submitMvpVote({
    required String matchId,
    required String votedUserId,
  }) async {
    // Önce konumu almayı dene
    Position? currentPosition;
    try {
      // Konum provider'ının mevcut değerini (veya hatasını) al
      currentPosition = await _ref.read(currentPositionProvider.future);
    } catch (e) {
      // Konum alınamazsa hata ver
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Oy kullanmak için konumunuz alınamadı.',
      );
      return false;
    }

    // Konum varsa oylama işlemine başla
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _votesRepository.submitMvpVote(
        matchId: matchId,
        votedUserId: votedUserId,
        currentPosition: currentPosition!,
      );
      if (mounted) {
        state = state.copyWith(isSubmitting: false, hasVotedMvp: true);
      }
      // Başarı sonrası MatchDetail ekranının yenilenmesi gerekebilir
      // _ref.invalidate(matchDetailProvider(matchId)); // Belki oy kullanıldı bilgisi için
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      return false;
    }
  }

  // Etiket Oyu Gönderme Metodu
  Future<bool> submitTagVote({
    required String matchId,
    required String taggedUserId,
    required String tagId,
  }) async {
    Position? currentPosition;
    try {
      currentPosition = await _ref.read(currentPositionProvider.future);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Oy kullanmak için konumunuz alınamadı.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      debugPrint(
        '>>> Oy İsteği Gönderiliyor - MaçID: $matchId, KullanıcıKonumu: Lat=${currentPosition!.latitude}, Lon=${currentPosition.longitude}',
      );
      await _votesRepository.submitTagVote(
        matchId: matchId,
        taggedUserId: taggedUserId,
        tagId: tagId,
        currentPosition: currentPosition,
      );
      if (mounted) {
        state = state.copyWith(isSubmitting: false, hasVotedTag: true);
      }
      // _ref.invalidate(matchDetailProvider(matchId));
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      return false;
    }
  }

  // --- YENİ METOD: Hata Mesajını Temizle ---
  void clearError() {
    if (mounted && state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  // --- YENİ METOD: State'i sıfırla (kullanıcı veya maç değiştiğinde çağır) ---
  void reset() {
    if (mounted) {
      state = const VotesState();
    }
  }

  // --- YENİ METOD: Sunucudan oy durumunu çek ---
  Future<void> fetchMyVoteStatus(String matchId) async {
    try {
      final result = await _votesRepository.fetchMyVoteStatus(matchId: matchId);
      if (mounted) {
        state = state.copyWith(
          hasVotedMvp: result.$1,
          hasVotedTag: result.$2,
          clearError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }
}

// VotesNotifier'ı sağlayan Provider
final votesNotifierProvider = StateNotifierProvider<VotesNotifier, VotesState>((
  ref,
) {
  final votesRepository = ref.watch(votesRepositoryProvider);
  return VotesNotifier(votesRepository, ref); // ref'i de gönderiyoruz
});
