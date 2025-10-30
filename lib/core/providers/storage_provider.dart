// lib/core/providers/storage_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Riverpod'a FlutterSecureStorage'ın bir örneğini 'provider' olarak tanıtıyoruz
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});
