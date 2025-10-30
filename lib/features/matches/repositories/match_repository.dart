// lib/features/matches/repositories/match_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/models/match_participant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/core/providers/dio_provider.dart';
import 'package:flutter_baab_sport_field_app/models/match.dart';
// Match modelini tanımlamamız gerekecek (şimdilik Map kullanabiliriz)

// MatchRepository Provider'ı
final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MatchRepository(dio: dio);
});

class MatchRepository {
  final Dio _dio;
  MatchRepository({required Dio dio}) : _dio = dio;

  // Yakındaki maçları getiren fonksiyon
  Future<List<Map<String, dynamic>>> findNearbyMatches({
    required double latitude,
    required double longitude,
    int radius = 20000, // Varsayılan 20km
  }) async {
    try {
      // GET /matches isteği (Token gerektirir!)
      final response = await _dio.get(
        '/matches', // Backend'deki findPublicMatches endpoint'i
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        },
        // TODO: Token'ı Header'a eklememiz gerekiyor!
      );

      if (response.statusCode == 200 && response.data is List) {
        // Gelen Listeyi Map listesine çevir
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw Exception('Maçlar alınamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      debugPrint('Maçları alma hatası: ${e.response?.data['message']}');
      throw Exception(e.response?.data['message'] ?? 'Maçlar alınamadı');
    } catch (e) {
      debugPrint('Bilinmeyen hata: $e');
      throw Exception('Maçlar alınırken bilinmeyen bir hata oluştu');
    }
  }

  // TODO: getMatchDetails(String matchId)
  // ----- YENİ FONKSİYON: Maç Detaylarını Getir -----
  Future<Match> getMatchDetails(String matchId) async {
    try {
      // GET /matches/{matchId} (Token gerektirir)
      final response = await _dio.get('/matches/$matchId');

      if (response.statusCode == 200 && response.data is Map) {
        return Match.fromJson(response.data as Map<String, dynamic>);
        //Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Maç detayı alınamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      print('Maç detayı alma hatası: ${e.response?.data['message']}');
      // 404 Not Found durumunu özel olarak ele alabiliriz
      if (e.response?.statusCode == 404) {
        throw Exception('Maç bulunamadı.');
      }
      throw Exception(e.response?.data['message'] ?? 'Maç detayı alınamadı');
    } catch (e) {
      print('Bilinmeyen hata: $e');
      throw Exception('Maç detayı alınırken bilinmeyen bir hata oluştu');
    }
  }

  // TODO: createMatch(...)
  // ----- YENİ FONKSİYON: Maç Oluştur -----
  Future<Map<String, dynamic>> createMatch({
    required String fieldId,
    required String startTimeIso, // ISO 8601 formatında UTC
    required int durationMinutes,
    required String format,
    String? privacyType, // 'public' veya 'private'
    String? joinType, // 'open' veya 'approval_required'
    String? notes,
  }) async {
    try {
      // POST /matches (Token gerektirir)
      final response = await _dio.post(
        '/matches',
        data: {
          'field_id': fieldId,
          'start_time': startTimeIso,
          'duration_minutes': durationMinutes,
          'format': format,
          'privacy_type': privacyType ?? 'public', // Varsayılan public
          'join_type': joinType ?? 'open', // Varsayılan open
          'notes': notes,
        },
      );

      if (response.statusCode == 201 && response.data is Map) {
        // Başarıyla oluşturulan maç verisini döndür
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Maç oluşturulamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      debugPrint('Maç oluşturma hatası: ${e.response?.data['message']}');
      throw Exception(e.response?.data['message'] ?? 'Maç oluşturulamadı');
    } catch (e) {
      debugPrint('Bilinmeyen hata: $e');
      throw Exception('Maç oluşturulurken bilinmeyen bir hata oluştu');
    }
  }

  // ----- YENİ FONKSİYON: Maça Katıl/Başvur -----
  Future<MatchParticipant> joinMatch({
    required String matchId,
    String? positionRequest,
  }) async {
    try {
      // POST /matches/{matchId}/join (Token gerektirir)
      final response = await _dio.post(
        '/matches/$matchId/join',
        data: {'position_request': positionRequest},
      );

      // Backend yeni oluşturulan MatchParticipant kaydını döndürür
      if (response.statusCode == 201 && response.data is Map) {
        return MatchParticipant.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Maça katılamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      debugPrint('Maça katılma hatası: ${e.response?.data['message']}');
      // Spesifik hataları (409 Conflict - Zaten Katılmış, 403 Forbidden - Kadro Dolu) yakala
      if (e.response?.statusCode == 409 || e.response?.statusCode == 403) {
        throw Exception(e.response?.data['message'] ?? 'İşlem Başarısız');
      }
      throw Exception(e.response?.data['message'] ?? 'Maça katılamadı');
    } catch (e) {
      debugPrint('Bilinmeyen hata: $e');
      throw Exception('Maça katılırken bilinmeyen bir hata oluştu');
    }
  }

  // ----- YENİ FONKSİYON: Maçtan Ayrıl -----
  Future<void> leaveMatch({required String matchId}) async {
    try {
      // DELETE /matches/{matchId}/leave (Token gerektirir)
      final response = await _dio.delete('/matches/$matchId/leave');

      // Başarılı silme genellikle 200 OK veya 204 No Content döndürür
      if (response.statusCode != 200 && response.statusCode != 204) {
        // Backend'imiz 200 OK ve bir mesaj döndürüyordu
        throw Exception(
          'Maçtan ayrılamadı: Beklenmeyen yanıt ${response.statusCode}',
        );
      }
      // Başarılıysa bir şey döndürmeye gerek yok
    } on DioException catch (e) {
      debugPrint('Maçtan ayrılma hatası: ${e.response?.data['message']}');
      // Spesifik hataları (403 Forbidden - Kaptan Ayrılamaz, 404 Not Found - Zaten Kayıtlı Değil) yakala
      if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
        throw Exception(e.response?.data['message'] ?? 'İşlem Başarısız');
      }
      throw Exception(e.response?.data['message'] ?? 'Maçtan ayrılamadı');
    } catch (e) {
      debugPrint('Bilinmeyen hata: $e');
      throw Exception('Maçtan ayrılırken bilinmeyen bir hata oluştu');
    }
  }

  // ----- YENİ FONKSİYON: Katılımcı Statüsünü Güncelle (Onayla/Reddet) -----
  Future<Map<String, dynamic>> updateParticipantStatus({
    required String matchId,
    required String participantId, // match_participants kaydının ID'si
    required String status, // 'accepted' veya 'declined'
  }) async {
    try {
      // PATCH /matches/{matchId}/participants/{participantId} (Token gerektirir)
      final response = await _dio.patch(
        '/matches/$matchId/participants/$participantId',
        data: {'status': status}, // Gövdede yeni statüyü gönder
      );

      // Backend güncellenmiş (veya silinmişse geçici) kaydı döndürür
      if (response.statusCode == 200 && response.data is Map) {
        // Declined durumunda backend geçici bir nesne döndürebilir,
        // bunu da parse edebilmeliyiz.
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Katılımcı durumu güncellenemedi: Beklenmeyen format');
      }
    } on DioException catch (e) {
      print('Katılımcı güncelleme hatası: ${e.response?.data['message']}');
      // Spesifik hataları (403 Forbidden - Kaptan Değil / Kadro Dolu / Statü Yanlış, 404 Not Found) yakala
      if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
        throw Exception(e.response?.data['message'] ?? 'İşlem Başarısız');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Katılımcı durumu güncellenemedi',
      );
    } catch (e) {
      print('Bilinmeyen hata: $e');
      throw Exception(
        'Katılımcı durumu güncellenirken bilinmeyen bir hata oluştu',
      );
    }
  }

  // ----- YENİ METOD: Kaptan Katılım Onayı -----
  Future<void> submitAttendance({
    required String matchId,
    required List<String> noShowUserIds, // Gelmeyenlerin listesi
  }) async {
    try {
      // POST /matches/{matchId}/attendance (Token gerektirir)
      final response = await _dio.post(
        '/matches/$matchId/attendance',
        data: {'noShowUserIds': noShowUserIds},
      );

      if (response.statusCode != 201) {
        // Backend 201 Created döndürmeli
        throw Exception(
          'Katılım onayı gönderilemedi: Beklenmeyen yanıt ${response.statusCode}',
        );
      }
      // Başarılıysa bir şey döndürmeye gerek yok
    } on DioException catch (e) {
      print('Katılım onayı hatası: ${e.response?.data['message']}');
      // Spesifik hataları (403 Forbidden - Kaptan Değil) yakala
      if (e.response?.statusCode == 403) {
        throw Exception(e.response?.data['message'] ?? 'İşlem Başarısız');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Katılım onayı gönderilemedi',
      );
    } catch (e) {
      print('Bilinmeyen hata: $e');
      throw Exception('Katılım onayı gönderilirken bilinmeyen bir hata oluştu');
    }
  }

  // TODO: joinMatch(String matchId, ...)
  // TODO: leaveMatch(String matchId)
  // TODO: updateParticipantStatus(...)
  // TODO: updateAttendance(...)
  // TODO: submitMatchAttendance(...)
}
