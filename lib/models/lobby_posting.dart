// lib/models/lobby_posting.dart

import 'package:flutter_baab_sport_field_app/models/field.dart';
import 'package:flutter_baab_sport_field_app/models/user.dart';
import 'package:flutter_baab_sport_field_app/models/lobby_response.dart';

class LobbyPosting {
  final String id;
  final User creator; // creator_user_id yerine doğrudan User objesi
  final String type; // 'PLAYER_WANTED' | 'OPPONENT_WANTED'
  final String status; // 'open' | 'filled' | 'expired'
  final String title;
  final String? description;
  final Field? field; // field_id yerine doğrudan Field objesi
  final DateTime matchTime;
  final int teamSize;
  final int? playersNeeded;
  final String? positionNeeded;
  final DateTime createdAt;
  final List<LobbyResponse> responses;

  LobbyPosting({
    required this.id,
    required this.creator,
    required this.type,
    required this.status,
    required this.title,
    this.description,
    this.field,
    required this.matchTime,
    required this.teamSize,
    this.playersNeeded,
    this.positionNeeded,
    required this.createdAt,
    required this.responses,
  });

  factory LobbyPosting.fromJson(Map<String, dynamic> json) {
    return LobbyPosting(
      id: json['id'],
      // Backend'de 'eager: true' yaptığımız için 'creator' objesi geliyor
      creator: User.fromJson(json['creator']),
      type: json['type'],
      status: json['status'],
      title: json['title'],
      description: json['description'],
      // Backend'de 'eager: true' yaptığımız için 'field' objesi geliyor
      field: json['field'] != null ? Field.fromJson(json['field']) : null,
      matchTime: DateTime.parse(json['match_time']),
      teamSize: json['team_size'],
      playersNeeded: json['players_needed'],
      positionNeeded: json['position_needed'],
      createdAt: DateTime.parse(json['created_at']),
      // Başvurular her zaman gelmeyebilir, özellikle /lobby listesinde
      // Detay sorgusunda gelirler
      responses:
          (json['responses'] as List<dynamic>?)
              ?.map((e) => LobbyResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
