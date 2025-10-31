// lib/features/lobby/repositories/lobby_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/core/providers/dio_provider.dart';
import 'package:flutter_baab_sport_field_app/models/lobby_posting.dart';

// 1. Repository Provider'ı
final lobbyRepositoryProvider = Provider<LobbyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LobbyRepository(dio: dio);
});

// 2. Repository Sınıfı
class LobbyRepository {
  final Dio _dio;
  LobbyRepository({required Dio dio}) : _dio = dio;

  // GET /lobby - Açık ilanları getir
  Future<List<LobbyPosting>> getOpenPosts() async {
    try {
      final response = await _dio.get('/lobby');

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data;
        final List<LobbyPosting> posts = [];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            try {
              posts.add(LobbyPosting.fromJson(item));
            } catch (_) {
              // Malformed item; skip
            }
          }
        }
        return posts;
      }
      throw Exception('Lobi ilanları alınamadı');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lobi yüklenemedi');
    } catch (e) {
      throw Exception('Bilinmeyen bir hata oluştu');
    }
  }

  // YENİ METOT: POST /lobby - Yeni ilan oluştur
  Future<LobbyPosting?> createPost({
    required String title,
    required String? description,
    required String type,
    required String? fieldId,
    required DateTime matchTime,
    required int teamSize,
    required int? playersNeeded,
    required String? positionNeeded,
  }) async {
    try {
      final response = await _dio.post(
        '/lobby',
        data: {
          'title': title,
          'description': description,
          'type': type, // 'PLAYER_WANTED' or 'OPPONENT_WANTED'
          'field_id': fieldId,
          'match_time': matchTime
              .toUtc()
              .toIso8601String(), // Her zaman UTC gönder
          'team_size': teamSize,
          'players_needed': playersNeeded,
          'position_needed': positionNeeded,
        },
      );

      if (response.statusCode == 201) {
        // Body parse etmeye gerek yok; success kabul et ve null döndür.
        return null;
      }
      throw Exception('Failed to create post');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to create post');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // TODO: Diğer API çağrıları buraya eklenecek
  // createPost, createResponse, acceptResponse vb.
}
