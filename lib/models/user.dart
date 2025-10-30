import 'package:flutter/foundation.dart'; // immutable için
import 'package:flutter_baab_sport_field_app/models/user_badge.dart';
import 'player_profile.dart'; // İlişki için

@immutable
class User {
  final String id;
  final String phoneNumber;
  final String fullName;
  final DateTime? birthDate; // String yerine DateTime olabilir (parse edilecek)
  final String? city;
  final String? state;
  final String? zipCode;
  final String? profileImageUrl;
  final DateTime createdAt;
  final PlayerProfile? playerProfile;
  final List<UserBadge> userBadges;

  const User({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.birthDate,
    this.city,
    this.state,
    this.zipCode,
    this.profileImageUrl,
    required this.createdAt,
    this.playerProfile,
    this.userBadges = const [],
  });

  // --- DAHA GÜVENLİ VE DETAYLI HATA KONTROLLÜ fromJson ---
  factory User.fromJson(Map<String, dynamic> json) {
    debugPrint(">>> Parsing User JSON: $json"); // Loglama ekleyelim

    // id (Zorunlu String)
    final String? id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw FormatException("User JSON'da 'id' eksik veya boş: $json");
    }

    // phoneNumber (Zorunlu String)
    final String? phoneNumber = json['phone_number'] as String?;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      throw FormatException(
        "User JSON'da 'phone_number' eksik veya boş: $json",
      );
    }

    // fullName (Zorunlu String)
    final String? fullName = json['full_name'] as String?;
    if (fullName == null || fullName.isEmpty) {
      throw FormatException("User JSON'da 'full_name' eksik veya boş: $json");
    }

    // createdAt (Zorunlu Tarih String'i)
    final String? createdAtStr = json['created_at'] as String?;
    if (createdAtStr == null || createdAtStr.isEmpty) {
      throw FormatException("User JSON'da 'created_at' eksik veya boş: $json");
    }
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(createdAtStr);
    } catch (e) {
      throw FormatException(
        "User JSON'da geçersiz 'created_at' formatı: '$createdAtStr'. Hata: $e",
      );
    }

    // Opsiyonel Alanlar
    final DateTime? birthDate = json['birth_date'] != null
        ? DateTime.tryParse(json['birth_date'] as String)
        : null;
    final String? city = json['city'] as String?;
    final String? state = json['state'] as String?;
    final String? zipCode = json['zip_code'] as String?;
    final String? profileImageUrl = json['profile_image_url'] as String?;

    // PlayerProfile (Opsiyonel İlişki)
    PlayerProfile? playerProfile;
    if (json['playerProfile'] != null &&
        json['playerProfile'] is Map<String, dynamic>) {
      try {
        playerProfile = PlayerProfile.fromJson(
          json['playerProfile'] as Map<String, dynamic>,
        );
      } catch (e) {
        // PlayerProfile parse hatasını logla ama User oluşturmaya devam et (veya hata fırlat)
        debugPrint("User JSON içinde PlayerProfile parse edilemedi: $e");
        // Hata fırlatmak daha doğru olabilir:
        // throw FormatException("User JSON içinde PlayerProfile parse edilemedi: $e");
      }
    }

    // --- YENİ: userBadges Listesini Parse Etme ---
    List<UserBadge> parseUserBadges(dynamic list) {
      if (list == null || list is! List) return []; // Boş liste döndür
      List<UserBadge> badges = [];
      for (var item in list) {
        try {
          badges.add(UserBadge.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint("UserBadge parse hatası: $e"); // Hatalı rozeti atla
        }
      }
      return badges;
    }

    debugPrint(">>> User parsing successful for id: $id");
    return User(
      id: id,
      phoneNumber: phoneNumber,
      fullName: fullName,
      birthDate: birthDate,
      city: city,
      state: state,
      zipCode: zipCode,
      profileImageUrl: profileImageUrl,
      createdAt: createdAt,
      playerProfile: playerProfile,
      userBadges: parseUserBadges(json['userBadges']),
    );
  }

  // --- GÜNCELLENMİŞ displayImageUrl getter'ı ---
  String get displayImageUrl {
    // Eğer profileImageUrl varsa onu kullan, yoksa yerel asset'i kullan
    return profileImageUrl?.isNotEmpty == true
        ? profileImageUrl!
        : 'assets/images/default_profile.jpg'; // Yerel placeholder resminizin yolu
  }
}
