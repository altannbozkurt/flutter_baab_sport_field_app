import 'package:flutter/foundation.dart';
import 'package:flutter_baab_sport_field_app/models/badge.dart';

@immutable
class UserBadge {
  final String id;
  final String userId;
  final String badgeId;
  final DateTime earnedAt;
  final Badge badge; // Backend'de 'eager: true' sayesinde bu nesne dolu gelecek

  const UserBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.earnedAt,
    required this.badge,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    final String? id = json['id'] as String?;
    final String? userId = json['user_id'] as String?;
    final String? badgeId = json['badge_id'] as String?;
    final String? earnedAtStr = json['earned_at'] as String?;
    final Map<String, dynamic>? badgeData =
        json['badge'] as Map<String, dynamic>?;

    if (id == null ||
        userId == null ||
        badgeId == null ||
        earnedAtStr == null ||
        badgeData == null) {
      throw FormatException("UserBadge JSON'dan zorunlu alan eksik: $json");
    }

    DateTime earnedAt;
    try {
      earnedAt = DateTime.parse(earnedAtStr);
    } catch (e) {
      throw FormatException(
        "UserBadge JSON'da geçersiz 'earned_at' formatı: $earnedAtStr",
      );
    }

    return UserBadge(
      id: id,
      userId: userId,
      badgeId: badgeId,
      earnedAt: earnedAt,
      badge: Badge.fromJson(badgeData), // İç içe parse etme
    );
  }
}
