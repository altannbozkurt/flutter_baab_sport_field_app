import 'package:flutter/foundation.dart';
import 'user.dart'; // User modelini import et

typedef ParticipantStatus =
    String; // 'invited', 'requested', 'accepted', 'declined'

@immutable
class MatchParticipant {
  final String id;
  final String matchId;
  final String userId;
  final ParticipantStatus status;
  final String? positionRequest;
  final bool? attended; // Null olabilir (henüz onaylanmamış)
  final DateTime joinedAt;
  final User? user; // İlişkili User nesnesi (MatchDetail'de gelir)

  const MatchParticipant({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.status,
    this.positionRequest,
    this.attended,
    required this.joinedAt,
    this.user,
  });

  factory MatchParticipant.fromJson(Map<String, dynamic> json) {
    // Zorunlu alanları nullable olarak al
    final String? id = json['id'] as String?;
    final String? matchId = json['match_id'] as String?;
    final String? userId = json['user_id'] as String?;
    final String? status = json['status'] as String?;
    final String? joinedAtStr = json['joined_at'] as String?;

    // Zorunlu alanlar eksikse hata fırlat
    if (id == null ||
        matchId == null ||
        userId == null ||
        status == null ||
        joinedAtStr == null) {
      throw FormatException(
        "MatchParticipant JSON'dan zorunlu alan eksik: $json",
      );
    }

    return MatchParticipant(
      id: id,
      matchId: matchId,
      userId: userId,
      status: status,
      // Opsiyonel alanları nullable cast ile al
      positionRequest: json['position_request'] as String?,
      attended: json['attended'] as bool?,
      joinedAt: DateTime.parse(joinedAtStr), // Null olmadığından eminiz
      // İlişkili 'user' nesnesini güvenli bir şekilde parse et
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
  // --- fromJson BİTTİ ---
}
