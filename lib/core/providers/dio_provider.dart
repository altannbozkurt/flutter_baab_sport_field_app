// lib/core/providers/dio_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'storage_provider.dart'; // <-- EKLE
import '../../features/auth/repositories/auth_repository.dart'; // <-- EKLE (_tokenKey için)
import 'dart:io' show Platform; // Android/iOS kontrolü için

// Riverpod'a Dio'nun bir örneğini 'provider' olarak tanıtıyoruz
final dioProvider = Provider<Dio>((ref) {
  // .env dosyasından API adresimizi alıyoruz
  final String baseUrl = Platform.isAndroid
      ? dotenv.env['API_BASE_URL_ANDROID']! // Android için 10.0.2.2
      : dotenv.env['API_BASE_URL']!; // iOS/Web için localhost

  final options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(
      seconds: 10,
    ), // 5 saniyede bağlanamazsa hata ver
    receiveTimeout: const Duration(seconds: 10),
  );

  final dio = Dio(options);

  // --- YENİ TOKEN INTERCEPTOR ---
  // Güvenli depoyu oku
  final storage = ref.watch(secureStorageProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // İstek gönderilmeden önce token'ı oku
        final token = await storage.read(
          key: AuthRepository.tokenKey,
        ); // _tokenKey yerine static yaptık

        // Eğer token varsa, Authorization header'ını ekle
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          debugPrint('>>> Token Added to Header'); // Debug için log
        } else {
          debugPrint('>>> No Token Found'); // Debug için log
        }
        // İsteğin devam etmesini sağla
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Eğer 401 Unauthorized hatası alırsak (token geçersiz veya süresi dolmuş)
        if (e.response?.statusCode == 401) {
          debugPrint('>>> Interceptor: Got 401 - Unauthorized');
          // TODO: Kullanıcıyı logout yapıp login ekranına yönlendir
          // Örn: ref.read(authNotifierProvider.notifier).logout();
          // Bu interceptor provider içinde olduğu için doğrudan ref.read kullanamayız.
          // Daha gelişmiş bir çözüm (Queue Interceptor) veya
          // hata yönetimini repository katmanında yapmak gerekir.
          // Şimdilik sadece loglayalım.
        }
        return handler.next(e); // Hatayı devam ettir
      },
    ),
  );
  // --- TOKEN INTERCEPTOR BİTTİ ---

  // İsteğe bağlı: Her isteği loglamak için bir "interceptor" ekleyebiliriz
  dio.interceptors.add(
    LogInterceptor(requestHeader: true, requestBody: true, responseBody: true),
  );

  return dio;
});
