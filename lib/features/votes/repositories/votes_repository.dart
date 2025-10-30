// lib/features/votes/repositories/votes_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart'; // Konum göndermek için
import 'package:flutter_baab_sport_field_app/core/providers/dio_provider.dart';
// TODO: Vote modelleri (MatchMvpVote, MatchTagVote) oluşturulabilir (opsiyonel)

// VotesRepository Provider'ı
final votesRepositoryProvider = Provider<VotesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return VotesRepository(dio: dio);
});

class VotesRepository {
  final Dio _dio;
  VotesRepository({required Dio dio}) : _dio = dio;

  // ----- MVP Oyu Gönderme -----
  Future<void> submitMvpVote({
    required String matchId,
    required String votedUserId,
    required Position currentPosition, // Oynanma Kanıtı için konum
  }) async {
    try {
      // POST /votes/matches/{matchId}/mvp (Token gerektirir)
      final response = await _dio.post(
        '/votes/matches/$matchId/mvp',
        data: {
          'voted_user_id': votedUserId,
          'latitude': currentPosition.latitude,
          'longitude': currentPosition.longitude,
        },
      );

      // Başarılı (201 Created)
      if (response.statusCode != 201) {
        throw Exception(
          'MVP oyu gönderilemedi: Beklenmeyen yanıt ${response.statusCode}',
        );
      }
      // Başarılıysa bir şey döndürmeye gerek yok
    } on DioException catch (e) {
      print('MVP oyu gönderme hatası: ${e.response?.data['message']}');
      // Spesifik hataları (400 Kendine Oy, 403 Zaman/Konum/Katılım Hatası, 409 Mükerrer Oy) yakala
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 403 ||
          e.response?.statusCode == 409) {
        throw Exception(e.response?.data['message'] ?? 'İşlem Başarısız');
      }
      throw Exception(e.response?.data['message'] ?? 'MVP oyu gönderilemedi');
    } catch (e) {
      print('Bilinmeyen hata: $e');
      throw Exception('MVP oyu gönderilirken bilinmeyen bir hata oluştu');
    }
  }

  // ----- Etiket Oyu Gönderme -----
  Future<void> submitTagVote({
    required String matchId,
    required String taggedUserId,
    required String tagId, // Örn: 'FINISHING', 'DEFENDING'
    required Position currentPosition, // Oynanma Kanıtı için konum
  }) async {
    try {
      // POST /votes/matches/{matchId}/tag (Token gerektirir)
      final response = await _dio.post(
        '/votes/matches/$matchId/tag',
        data: {
          'tagged_user_id': taggedUserId,
          'tag_id': tagId,
          'latitude': currentPosition.latitude,
          'longitude': currentPosition.longitude,
        },
      );

      if (response.statusCode != 201) {
        throw Exception(
          'Etiket oyu gönderilemedi: Beklenmeyen yanıt ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('Etiket oyu gönderme hatası: ${e.response?.data['message']}');
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 403 ||
          e.response?.statusCode == 409) {
        throw Exception(e.response?.data['message'] ?? 'İşlem Başarısız');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Etiket oyu gönderilemedi',
      );
    } catch (e) {
      print('Bilinmeyen hata: $e');
      throw Exception('Etiket oyu gönderilirken bilinmeyen bir hata oluştu');
    }
  }

  // ----- Oy Durumunu Sorgula -----
  Future<(bool hasVotedMvp, bool hasVotedTag)> fetchMyVoteStatus({
    required String matchId,
  }) async {
    try {
      final response = await _dio.get('/votes/matches/$matchId/me');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final hasMvp = (data['has_voted_mvp'] as bool?) ?? false;
        final hasTag = (data['has_voted_tag'] as bool?) ?? false;
        return (hasMvp, hasTag);
      }
      throw Exception('Oy durumu alınamadı: Beklenmeyen yanıt ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Oy durumu alınamadı');
    } catch (e) {
      throw Exception('Oy durumu alınırken bilinmeyen bir hata oluştu');
    }
  }
}
