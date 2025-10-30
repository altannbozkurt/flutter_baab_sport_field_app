// lib/features/fields/repositories/field_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/core/providers/dio_provider.dart';
// TODO: Field modeli oluşturulacak

// FieldRepository Provider'ı
final fieldRepositoryProvider = Provider<FieldRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FieldRepository(dio: dio);
});

class FieldRepository {
  final Dio _dio;
  FieldRepository({required Dio dio}) : _dio = dio;

  // Yakındaki sahaları getiren fonksiyon
  Future<List<Map<String, dynamic>>> findNearbyFields({
    required double latitude,
    required double longitude,
    int radius = 20000,
  }) async {
    try {
      // GET /fields/nearby (Token gerektirir)
      final response = await _dio.get(
        '/fields/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw Exception('Sahalar alınamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      debugPrint('Sahaları alma hatası: ${e.response?.data['message']}');
      throw Exception(e.response?.data['message'] ?? 'Sahalar alınamadı');
    } catch (e) {
      debugPrint('Bilinmeyen hata: $e');
      throw Exception('Sahalar alınırken bilinmeyen bir hata oluştu');
    }
  }

  // TODO: createField(...) // Flutter'dan saha eklemek istersek
}
