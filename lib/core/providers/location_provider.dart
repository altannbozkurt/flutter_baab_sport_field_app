// lib/core/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';

// Konum servisinin durumunu ve son konumu tutacak state
class LocationState {
  final bool serviceEnabled;
  final LocationPermission permission;
  final Position? position;
  final String? error;

  LocationState({
    required this.serviceEnabled,
    required this.permission,
    this.position,
    this.error,
  });
}

// Konumu yönetecek Notifier
class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier()
    : super(
        LocationState(
          serviceEnabled: false,
          permission: LocationPermission.denied,
        ),
      ) {
    _initLocation(); // Başlangıçta konumu almayı dene
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Konum servisleri açık mı?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = LocationState(
        serviceEnabled: false,
        permission: LocationPermission
            .deniedForever, // Servis kapalıysa izin de yok sayılır
        error: 'Konum servisleri kapalı.',
      );
      return;
    }

    // 2. İzin durumu nedir?
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // İzin istenmemişse, iste
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = LocationState(
          serviceEnabled: true,
          permission: permission,
          error: 'Konum izni reddedildi.',
        );
        return;
      }
    }

    // 3. İzin kalıcı olarak reddedilmiş mi?
    if (permission == LocationPermission.deniedForever) {
      state = LocationState(
        serviceEnabled: true,
        permission: permission,
        error: 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.',
      );
      return;
    }

    // 4. İzinler tamsa, konumu al
    try {
      Position position = await Geolocator.getCurrentPosition();
      state = LocationState(
        serviceEnabled: true,
        permission: permission,
        position: position,
      );
    } catch (e) {
      state = LocationState(
        serviceEnabled: true,
        permission: permission,
        error: 'Konum alınamadı: $e',
      );
    }
  }

  // Kullanıcıya tekrar izin isteme veya ayarları açma butonu sunmak için
  Future<void> requestPermissionAgain() async {
    if (state.permission == LocationPermission.deniedForever) {
      // Ayarları açtır
      await Geolocator.openAppSettings();
    } else {
      // Tekrar izin iste (veya _initLocation'ı tekrar çağır)
      await _initLocation();
    }
  }
}

// LocationNotifier'ı sağlayan Provider
final locationNotifierProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
      return LocationNotifier();
    });

// Sadece 'Position' nesnesini kolayca almak için bir FutureProvider (isteğe bağlı)
// Kullanımı: ref.watch(currentPositionProvider).when(...)
final currentPositionProvider = FutureProvider<Position>((ref) async {
  final locationState = ref.watch(locationNotifierProvider);

  if (locationState.position != null) {
    return locationState.position!;
  }
  // Eğer başlangıçta konum alınamadıysa veya izin yoksa hata fırlat
  else if (locationState.error != null) {
    throw Exception(locationState.error);
  }
  // Henüz yükleniyorsa beklemesini sağlayacak bir Future döndür
  else {
    // Notifier state'i güncelleyene kadar bekleyelim (küçük bir gecikmeyle)
    await Future.delayed(const Duration(milliseconds: 100));
    // State güncellendikten sonra tekrar oku
    final updatedState = ref.read(locationNotifierProvider);
    if (updatedState.position != null) return updatedState.position!;
    throw Exception(updatedState.error ?? "Konum bekleniyor...");
  }
});
