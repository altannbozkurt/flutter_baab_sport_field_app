import 'package:flutter/foundation.dart';

@immutable
class Badge {
  final String id;
  final String name;
  final String description;
  final String tier;
  final String? iconUrl; // icon_url'i nullable yaptık

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    this.iconUrl,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    final String? id = json['id'] as String?;
    final String? name = json['name'] as String?;
    final String? description = json['description'] as String?;
    final String? tier = json['tier'] as String?;

    if (id == null || name == null || description == null || tier == null) {
      throw FormatException("Badge JSON'dan zorunlu alan eksik: $json");
    }

    return Badge(
      id: id,
      name: name,
      description: description,
      tier: tier,
      iconUrl: json['icon_url'] as String?, // Nullable
    );
  }
}
