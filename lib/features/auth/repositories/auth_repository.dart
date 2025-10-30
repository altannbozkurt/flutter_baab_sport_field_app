// lib/features/auth/repositories/auth_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_baab_sport_field_app/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_baab_sport_field_app/core/providers/dio_provider.dart';
import 'package:flutter_baab_sport_field_app/core/providers/storage_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(dio: dio, storage: storage);
});

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const String _tokenKey = 'access_token';
  static String get tokenKey => _tokenKey;

  AuthRepository({required Dio dio, required FlutterSecureStorage storage})
    : _dio = dio,
      _storage = storage;

  Future<void> login({required String phoneNumber}) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'phone_number': phoneNumber},
      );

      // Sadece 200 OK olduğunda başarılı kabul et
      if (response.statusCode == 200) {
        final String accessToken = response.data['access_token'];
        await _storage.write(key: _tokenKey, value: accessToken);
      } else {
        throw Exception('Sunucudan beklenmeyen yanıt: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = e.response?.data['message'];

      // Hata durumunda eski token varsa temizle
      try {
        await _storage.delete(key: _tokenKey);
      } catch (_) {}

      // 🔴 404 = kullanıcı bulunamadı
      if (status == 404) {
        throw Exception('Bu telefon numarasına sahip bir kullanıcı bulunamadı');
      }

      // 🔴 Diğer hatalar
      throw Exception(message ?? 'Giriş yapılamadı (${e.message})');
    } catch (e) {
      debugPrint('Bilinmeyen hata: $e');
      // Her ihtimale karşı token'ı temizle
      try {
        await _storage.delete(key: _tokenKey);
      } catch (_) {}
      throw Exception('Bilinmeyen bir hata oluştu');
    }
  }

  Future<void> register({
    required String phoneNumber,
    required String fullName,
    String? birthDate,
    String? city,
    String? state,
    String? zipCode,
  }) async {
    try {
      await _dio.post(
        '/auth/register',
        data: {
          'phone_number': phoneNumber,
          'full_name': fullName,
          'birth_date': birthDate,
          'city': city,
          'state': state,
          'zip_code': zipCode,
        },
      );

      await login(phoneNumber: phoneNumber);
    } on DioException catch (e) {
      final message = e.response?.data['message'];
      throw Exception(message ?? 'Kayıt yapılamadı');
    } catch (e) {
      throw Exception('Bilinmeyen bir hata oluştu');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('Token okuma hatası: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('Logout hatası: $e');
    }
  }

  // ----- YENİ METOD: Mevcut Kullanıcı Detaylarını Getir -----
  Future<User> getCurrentUserDetails() async {
    try {
      // GET /profile/me (Token gerektirir - Dio interceptor halleder)
      // Backend bu endpointte tam User nesnesi döndürüyor
      final response = await _dio.get('/profile/me');

      if (response.statusCode == 200 && response.data is Map) {
        // Gelen JSON'ı User modeline çevir
        return User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Kullanıcı detayları alınamadı: Beklenmeyen format');
      }
    } on DioException catch (e) {
      print('Kullanıcı detayları alma hatası: ${e.response?.data['message']}');
      // Token geçersizse (401) veya kullanıcı bulunamazsa (404) logout tetiklenebilir
      if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
        // Belki burada token'ı silmek iyi bir fikir olabilir? Veya çağıran yer (Notifier) karar versin.
        // await _storage.delete(key: tokenKey);
        throw Exception(
          e.response?.data['message'] ?? 'Kullanıcı bilgisi alınamadı.',
        );
      }
      throw Exception(
        e.response?.data['message'] ?? 'Kullanıcı detayları alınamadı',
      );
    } catch (e) {
      print('Bilinmeyen hata: $e');
      throw Exception(
        'Kullanıcı detayları alınırken bilinmeyen bir hata oluştu: $e',
      );
    }
  }
}
