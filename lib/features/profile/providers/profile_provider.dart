// lib/features/profile/providers/profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/features/profile/repositories/profile_repository.dart';
import 'package:flutter_baab_sport_field_app/models/player_profile.dart'; // Modeli import et
import 'package:flutter_baab_sport_field_app/models/user.dart'; // Modeli import et

// FutureProvider, repository'yi çağırır ve sonucu (loading/error/data) yönetir.
final userProfileProvider = FutureProvider.autoDispose<PlayerProfile>((
  ref,
) async {
  // ProfileRepository'yi oku
  final profileRepository = ref.watch(profileRepositoryProvider);
  // Repository'deki fonksiyonu çağır ve sonucu (Future) döndür
  return profileRepository.getMyProfile();
});

// ----- YENİ PROVIDER: ID ile User+PlayerProfile getiren -----
final userProfileByIdProvider = FutureProvider.autoDispose.family<User, String>(
  (ref, userId) async {
    // .family ile userId parametresini alırız
    final profileRepository = ref.watch(profileRepositoryProvider);
    // Yeni repository metodunu çağırırız
    return profileRepository.getUserProfileById(userId);
  },
);
