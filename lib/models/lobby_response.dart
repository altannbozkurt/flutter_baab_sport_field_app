// lib/models/lobby_response.dart

import 'package:flutter_baab_sport_field_app/models/user.dart';

class LobbyResponse {
  final String id;
  final String postId;
  final User responder; // responder_user_id yerine User objesi
  final String? message;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime createdAt;

  LobbyResponse({
    required this.id,
    required this.postId,
    required this.responder,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory LobbyResponse.fromJson(Map<String, dynamic> json) {
    return LobbyResponse(
      id: json['id'],
      postId: json['post_id'],
      // 'eager: true' sayesinde 'responder' objesi geliyor
      responder: User.fromJson(json['responder']),
      message: json['message'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
