import 'package:flutter/foundation.dart';
import 'field.dart';
import 'user.dart';
import 'match_participant.dart';

typedef MatchPrivacy = String; // 'public', 'private'
typedef MatchJoinType = String; // 'open', 'approval_required'
typedef MatchStatus = String; // 'scheduled', 'completed', 'cancelled'

@immutable
class Match {
  final String id;
  final String organizerId;
  final String fieldId;
  final DateTime startTime;
  final int durationMinutes;
  final String format;
  final MatchPrivacy privacyType;
  final MatchJoinType joinType;
  final MatchStatus status;
  final String? notes;
  final DateTime createdAt;

  // İlişkili nesneler (MatchDetail'de gelir)
  final Field? field;
  final User? organizer;
  final List<MatchParticipant>? participants;

  const Match({
    required this.id,
    required this.organizerId,
    required this.fieldId,
    required this.startTime,
    required this.durationMinutes,
    required this.format,
    required this.privacyType,
    required this.joinType,
    required this.status,
    this.notes,
    required this.createdAt,
    this.field,
    this.organizer,
    this.participants,
  });

  // --- GÜNCELLENMİŞ fromJson ---
  factory Match.fromJson(Map<String, dynamic> json) {
    // Zorunlu alanları nullable olarak al
    final String? id = json['id'] as String?;
    final String? organizerId = json['organizer_id'] as String?;
    final String? fieldId = json['field_id'] as String?;
    final String? startTimeStr = json['start_time'] as String?;
    final int? durationMinutes = json['duration_minutes'] as int?;
    final String? format = json['format'] as String?;
    final String? privacyType = json['privacy_type'] as String?;
    final String? joinType = json['join_type'] as String?;
    final String? status = json['status'] as String?;
    final String? createdAtStr = json['created_at'] as String?;

    // Zorunlu alanlar eksikse hata fırlat
    if (id == null ||
        organizerId == null ||
        fieldId == null ||
        startTimeStr == null ||
        durationMinutes == null ||
        format == null ||
        privacyType == null ||
        joinType == null ||
        status == null ||
        createdAtStr == null) {
      throw FormatException("Match JSON'dan zorunlu alan eksik: $json");
    }

    // Katılımcı listesini güvenli bir şekilde parse et
    List<MatchParticipant>? parseParticipants(dynamic participantList) {
      // Önce listenin var olup olmadığını ve List tipinde olup olmadığını kontrol et
      if (participantList == null || participantList is! List) return null;

      List<MatchParticipant> result = [];
      for (var p in participantList) {
        // Listedeki her elemanın Map olup olmadığını kontrol et
        if (p != null && p is Map<String, dynamic>) {
          try {
            result.add(MatchParticipant.fromJson(p));
          } catch (e) {
            // Hatalı katılımcı verisini logla ama devam et (veya hata fırlatılabilir)
            debugPrint("Katılımcı parse edilemedi: $p, Hata: $e");
          }
        }
      }
      return result;
    }

    return Match(
      id: id,
      organizerId: organizerId,
      fieldId: fieldId,
      startTime: DateTime.parse(startTimeStr),
      durationMinutes: durationMinutes,
      format: format,
      privacyType: privacyType,
      joinType: joinType,
      status: status,
      notes: json['notes'] as String?, // Opsiyonel
      createdAt: DateTime.parse(createdAtStr),
      // İlişkili nesneleri güvenli bir şekilde parse et
      field: json['field'] != null && json['field'] is Map<String, dynamic>
          ? Field.fromJson(json['field'] as Map<String, dynamic>)
          : null,
      organizer:
          json['organizer'] != null && json['organizer'] is Map<String, dynamic>
          ? User.fromJson(json['organizer'] as Map<String, dynamic>)
          : null,
      participants: parseParticipants(
        json['participants'],
      ), // Yardımcı fonksiyonu kullan
    );
  }

  // Maksimum kapasiteyi hesaplamak için yardımcı getter
  int get maxCapacity {
    try {
      final parts = format.toLowerCase().split('v');
      if (parts.length == 2) {
        final capacity = int.tryParse(parts[0]);
        if (capacity != null) return capacity * 2;
      }
    } catch (_) {}
    return 0; // Hata durumunda 0 döndür
  }

  // Kabul edilen katılımcı sayısını hesaplamak için getter
  int get acceptedParticipantCount {
    return participants?.where((p) => p.status == 'accepted').length ?? 0;
  }
}
