// lib/features/profile/repositories/profile_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/core/providers/dio_provider.dart';
import 'package:flutter_baab_sport_field_app/models/player_profile.dart'; // PlayerProfile modelini import et

// ProfileRepository Provider'ı
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileRepository(dio: dio);
});

class ProfileRepository {
  final Dio _dio;
  ProfileRepository({required Dio dio}) : _dio = dio;

  // Giriş yapmış kullanıcının profilini getiren fonksiyon
  Future<PlayerProfile> getMyProfile() async {
    try {
      // GET /profile/me (Token gerektirir)
      final response = await _dio.get('/profile/me');

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        // API iki şekilde dönebilir:
        // 1) Doğrudan PlayerProfile alanları (user_id, card_type, ...)
        // 2) Tam User nesnesi içinde nested playerProfile
        if (data.containsKey('user_id') && data.containsKey('card_type')) {
          return PlayerProfile.fromJson(data);
        }
        if (data['playerProfile'] is Map) {
          return PlayerProfile.fromJson(
            (data['playerProfile'] as Map).cast<String, dynamic>(),
          );
        }
        throw Exception('Profil alınamadı: Beklenmeyen JSON yapısı');
      } else {
        throw Exception('Profil alınamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      debugPrint('Profil alma hatası: ${e.response?.data['message']}');
      // 401 Unauthorized (token yok/geçersiz) veya 404 Not Found (profil bulunamadı)
      if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
        throw Exception(
          e.response?.data['message'] ?? 'Profil bilgisi alınamadı.',
        );
      }
      throw Exception(e.response?.data['message'] ?? 'Profil alınamadı');
    } catch (e) {
      debugPrint('Bilinmeyen hata: $e');
      throw Exception('Profil alınırken bilinmeyen bir hata oluştu: $e');
    }
  }

  // ----- YENİ METOD: Başka bir kullanıcının profilini getirir -----
  // Backend User nesnesini (PlayerProfile dahil) döndürecek
  Future<User> getUserProfileById(String userId) async {
    try {
      // GET /users/{userId}/profile (Token gerektirir)
      final response = await _dio.get(
        '/users/$userId/profile',
      ); // Yeni endpoint

      if (response.statusCode == 200 && response.data is Map) {
        // Gelen JSON'ı User modeline çevir (User.fromJson playerProfile'ı da handle etmeli)
        return User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Kullanıcı profili alınamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      print('Kullanıcı profili alma hatası: ${e.response?.data['message']}');
      if (e.response?.statusCode == 404) {
        throw Exception('Kullanıcı bulunamadı.');
      }
      if (e.response?.statusCode == 401) {
        // Token geçersizse
        // Belki AuthNotifier'ı haberdar et?
        throw Exception(
          'Oturumunuz zaman aşımına uğradı. Lütfen tekrar giriş yapın.',
        );
      }
      throw Exception(
        e.response?.data['message'] ?? 'Kullanıcı profili alınamadı',
      );
    } catch (e) {
      print('Bilinmeyen hata: $e');
      throw Exception(
        'Kullanıcı profili alınırken bilinmeyen bir hata oluştu: $e',
      );
    }
  }

  // ----- YENİ METOD: Kendi profilimi güncelle (User döner) -----
  // PATCH /profile/me
  Future<User> updateMyProfile(Map<String, dynamic> updateData) async {
    try {
      final response = await _dio.patch('/profile/me', data: updateData);

      if (response.statusCode == 200 && response.data is Map) {
        return User.fromJson((response.data as Map).cast<String, dynamic>());
      }
      throw Exception('Profil güncellenemedi: Beklenmeyen format');
    } on DioException catch (e) {
      // Backend genellikle { message: string | string[] } döner
      final data = e.response?.data;
      String message = 'Profil güncellenemedi';
      if (data is Map && data['message'] != null) {
        if (data['message'] is List && (data['message'] as List).isNotEmpty) {
          message = (data['message'] as List).join('\n');
        } else if (data['message'] is String) {
          message = data['message'] as String;
        }
      }
      if (e.response?.statusCode == 401) {
        throw Exception(
          'Oturumunuz zaman aşımına uğradı. Lütfen tekrar giriş yapın.',
        );
      }
      throw Exception(message);
    } catch (e) {
      debugPrint('Bilinmeyen hata (updateMyProfile): $e');
      throw Exception('Profil güncellenirken bilinmeyen bir hata oluştu: $e');
    }
  }
}
