// lib/features/matches/providers/matches_notifier_provider.dart
import 'package:flutter_baab_sport_field_app/features/matches/providers/match_detail_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/core/providers/location_provider.dart'; // Konum için
import 'package:flutter_baab_sport_field_app/features/matches/repositories/match_repository.dart'; // Repository için
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meta/meta.dart';

// Maç listesinin durumunu tutacak state
@immutable
class MatchesState {
  final bool isLoading;
  final bool isCreating;
  final bool isJoiningOrLeaving; // Katılma/Ayrılma işlemi sürüyor <-- YENİ
  final bool isUpdatingParticipant; // <-- YENİ: Onay/Red işlemi sürüyor
  final bool isSubmittingAttendance; // <-- YENİ: Katılım onayı gönderme
  final String? errorMessage;
  final List<Map<String, dynamic>>
  matches; // Şimdilik Map, sonra Match Model olacak

  const MatchesState({
    this.isLoading = true, // Başlangıçta yükleniyor (konum bekleniyor)
    this.isCreating = false,
    this.isJoiningOrLeaving = false, // <-- Varsayılan false
    this.isUpdatingParticipant = false, // <-- Varsayılan false
    this.isSubmittingAttendance = false, // <-- YENİ: Varsayılan false
    this.errorMessage,
    this.matches = const [],
  });

  MatchesState copyWith({
    bool? isLoading,
    bool? isCreating,
    bool? isJoiningOrLeaving, // <-- Ekle
    bool? isUpdatingParticipant, // <-- Ekle
    bool? isSubmittingAttendance, // <-- YENİ: Ekle
    String? errorMessage,
    List<Map<String, dynamic>>? matches,
    bool clearError = false,
  }) {
    return MatchesState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isJoiningOrLeaving:
          isJoiningOrLeaving ?? this.isJoiningOrLeaving, // <-- Ekle
      isUpdatingParticipant:
          isUpdatingParticipant ?? this.isUpdatingParticipant, // <-- Ekle
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      matches: matches ?? this.matches,
    );
  }
}

// Maçları yönetecek Notifier
class MatchesNotifier extends StateNotifier<MatchesState> {
  final MatchRepository _matchRepository;
  final Ref _ref; // Diğer provider'ları okumak için

  MatchesNotifier(this._matchRepository, this._ref)
    : super(const MatchesState()) {
    // Konum provider'ını dinle
    _ref.listen<AsyncValue<Position>>(currentPositionProvider, (_, next) {
      // Konum hazırsa ve hata yoksa maçları getir
      next.when(
        data: (position) {
          if (mounted) {
            // Notifier dispose edilmemişse
            fetchNearbyMatches(position);
          }
        },
        error: (error, stackTrace) {
          if (mounted) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: error.toString(),
            );
          }
        },
        loading: () {},
      );
    });
  }

  // Maçları getiren asenkron fonksiyon
  Future<void> fetchNearbyMatches(Position position) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final matches = await _matchRepository.findNearbyMatches(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        state = state.copyWith(isLoading: false, matches: matches);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
    }
  }

  // Maç listesini manuel olarak yenilemek için (pull-to-refresh)
  Future<void> refreshMatches() async {
    // En son bilinen konumu tekrar oku (veya hata varsa yeniden başlat)
    final positionAsyncValue = _ref.read(currentPositionProvider);
    positionAsyncValue.when(
      data: (position) {
        if (mounted) {
          fetchNearbyMatches(position);
        }
      },
      error: (error, stackTrace) {
        // Konum hatası varsa state'i güncelle
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: error.toString(),
          );
        }
      },
      loading: () {},
    );
  }

  // ----- YENİ METOD: Maç Oluştur -----
  Future<bool> createMatch({
    // Başarı durumunu döndürsün
    required String fieldId,
    required String startTimeIso,
    required int durationMinutes,
    required String format,
    String? privacyType,
    String? joinType,
    String? notes,
  }) async {
    // Form gönderilirken yükleniyor yap, hatayı temizle
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      // Repository'yi çağır
      await _matchRepository.createMatch(
        fieldId: fieldId,
        startTimeIso: startTimeIso,
        durationMinutes: durationMinutes,
        format: format,
        privacyType: privacyType,
        joinType: joinType,
        notes: notes,
      );
      // Başarılıysa, yüklenmeyi bitir
      if (mounted) {
        state = state.copyWith(isCreating: false);
      }
      // Başarı sonrası listeyi yenileyebiliriz (opsiyonel)
      refreshMatches();
      return true; // Başarıyı bildir
    } catch (e) {
      // Hata varsa, yüklenmeyi bitir, hata mesajını ata
      if (mounted) {
        state = state.copyWith(
          isCreating: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      return false; // Başarısızlığı bildir
    }
  }

  // ----- YENİ METOD: Maça Katıl -----
  Future<bool> joinMatch({
    required String matchId,
    String? positionRequest,
  }) async {
    // İşlem başlarken yükleniyor yap, hatayı temizle
    state = state.copyWith(isJoiningOrLeaving: true, clearError: true);
    try {
      await _matchRepository.joinMatch(
        matchId: matchId,
        positionRequest: positionRequest,
      );
      if (mounted) {
        state = state.copyWith(isJoiningOrLeaving: false);
      }
      // Başarı sonrası detay ekranının yeniden yüklenmesini tetikle (veya listeyi yenile)
      _ref.invalidate(
        matchDetailProvider(matchId),
      ); // Detay provider'ını geçersiz kıl
      refreshMatches(); // Ana listeyi de yenileyelim
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isJoiningOrLeaving: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      return false;
    }
  }

  // ----- YENİ METOD: Maçtan Ayrıl -----
  Future<bool> leaveMatch({required String matchId}) async {
    state = state.copyWith(isJoiningOrLeaving: true, clearError: true);
    try {
      await _matchRepository.leaveMatch(matchId: matchId);
      if (mounted) {
        state = state.copyWith(isJoiningOrLeaving: false);
      }
      // Başarı sonrası detay ekranının yeniden yüklenmesini tetikle
      _ref.invalidate(matchDetailProvider(matchId));
      refreshMatches();
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isJoiningOrLeaving: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      return false;
    }
  }

  Future<bool> updateParticipantStatus({
    required String matchId,
    required String participantId,
    required String status, // 'accepted' veya 'declined'
  }) async {
    // İşlem başlarken yükleniyor yap, hatayı temizle
    state = state.copyWith(isUpdatingParticipant: true, clearError: true);
    try {
      await _matchRepository.updateParticipantStatus(
        matchId: matchId,
        participantId: participantId,
        status: status,
      );
      if (mounted) {
        state = state.copyWith(isUpdatingParticipant: false);
      }
      // Başarı sonrası detay ekranının yeniden yüklenmesini tetikle
      _ref.invalidate(matchDetailProvider(matchId));
      refreshMatches(); // Ana listeyi de yenile (katılımcı sayısı değişti)
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isUpdatingParticipant: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      return false;
    }
  }

  // ----- YENİ METOD: Kaptan Katılım Onayı -----
  Future<bool> submitAttendance({
    required String matchId,
    required List<String> noShowUserIds,
  }) async {
    state = state.copyWith(isSubmittingAttendance: true, clearError: true);
    try {
      await _matchRepository.submitAttendance(
        matchId: matchId,
        noShowUserIds: noShowUserIds,
      );
      if (mounted) {
        state = state.copyWith(isSubmittingAttendance: false);
      }
      // Başarı sonrası detay ekranının yeniden yüklenmesini tetikle
      // (Böylece "Katılımı Onayla" bölümü kaybolur)
      _ref.invalidate(matchDetailProvider(matchId));
      // Ana listeyi de yenile (belki maç statüsü değişir)
      refreshMatches();
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSubmittingAttendance: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      return false;
    }
  }

  // Hata temizleme metodu
  void clearError() {
    if (mounted && state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

// MatchesNotifier'ı sağlayan Provider
final matchesNotifierProvider =
    StateNotifierProvider<MatchesNotifier, MatchesState>((ref) {
      final matchRepository = ref.watch(matchRepositoryProvider);
      return MatchesNotifier(matchRepository, ref); // ref'i de gönderiyoruz
    });
