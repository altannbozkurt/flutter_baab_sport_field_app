import 'package:flutter/foundation.dart';

typedef CardLevel = String; // 'bronze', 'silver', 'gold'

@immutable
class PlayerProfile {
  final String userId;
  final CardLevel cardType;
  final int overallRating;
  final int statPac;
  final int statSho;
  final int statPas;
  final int statDri;
  final int statDef;
  final int statPhy;
  final int fairPlayScore;
  final String? preferredFoot; // Modelde nullable olmalı
  final String? preferredPosition; // Modelde nullable olmalı
  final double participationRate;
  final double cancellationRate;
  final double noShowRate;
  final DateTime updatedAt;

  const PlayerProfile({
    required this.userId,
    required this.cardType,
    required this.overallRating,
    required this.statPac,
    required this.statSho,
    required this.statPas,
    required this.statDri,
    required this.statDef,
    required this.statPhy,
    required this.fairPlayScore,
    this.preferredFoot, // Constructor'da required değil
    this.preferredPosition, // Constructor'da required değil
    required this.participationRate,
    required this.cancellationRate,
    required this.noShowRate,
    required this.updatedAt,
  });

  // --- GÜNCELLENMİŞ fromJson ---
  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    // Eğer yanlışlıkla tüm User JSON'u gönderildiyse, içinden playerProfile'ı çıkar
    if (!json.containsKey('user_id') && json['playerProfile'] is Map) {
      json = (json['playerProfile'] as Map).cast<String, dynamic>();
    }
    // Helper'lar aynı
    double parseDouble(dynamic value) =>
        double.tryParse(value?.toString() ?? '0.0') ?? 0.0;
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return double.tryParse(value)?.round() ?? 0;
      return 0;
    }

    // --- Zorunlu Alanları Güvenle Oku ve Kontrol Et ---
    final String? userId = json['user_id'] as String?;
    if (userId == null || userId.isEmpty) {
      throw FormatException(
        "PlayerProfile JSON'da 'user_id' eksik veya boş: $json",
      );
    }

    final String? cardType = json['card_type'] as String?;
    if (cardType == null || cardType.isEmpty) {
      throw FormatException(
        "PlayerProfile JSON'da 'card_type' eksik veya boş: $json",
      );
    }

    final String? updatedAtStr = json['updated_at'] as String?;
    if (updatedAtStr == null || updatedAtStr.isEmpty) {
      throw FormatException(
        "PlayerProfile JSON'da 'updated_at' eksik veya boş: $json",
      );
    }
    DateTime updatedAt;
    try {
      updatedAt = DateTime.parse(updatedAtStr);
    } catch (e) {
      throw FormatException(
        "PlayerProfile JSON'da geçersiz 'updated_at' formatı: '$updatedAtStr'. Hata: $e",
      );
    }
    // --- Kontroller Bitti ---

    return PlayerProfile(
      userId: userId, // Artık null olmadığından eminiz
      cardType: cardType, // Artık null olmadığından eminiz
      overallRating: parseInt(json['overall_rating']), // Helper ile güvenli
      statPac: parseInt(json['stat_pac']),
      statSho: parseInt(json['stat_sho']),
      statPas: parseInt(json['stat_pas']),
      statDri: parseInt(json['stat_dri']),
      statDef: parseInt(json['stat_def']),
      statPhy: parseInt(json['stat_phy']),
      fairPlayScore: parseInt(json['fair_play_score']),
      // --- Nullable Alanları Güvenle Oku ---
      preferredFoot: json['preferred_foot'] as String?, // 'as String?' kullan
      preferredPosition:
          json['preferred_position'] as String?, // 'as String?' kullan
      // --- Nullable Bitti ---
      participationRate: parseDouble(
        json['participation_rate'],
      ), // Helper ile güvenli
      cancellationRate: parseDouble(json['cancellation_rate']),
      noShowRate: parseDouble(json['no_show_rate']),
      updatedAt: updatedAt, // Artık null olmadığından eminiz
    );
  }
  // --- fromJson BİTTİ ---
}
