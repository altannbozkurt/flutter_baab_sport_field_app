import 'package:flutter/foundation.dart';

// GeoJSON Point formatı için basit bir sınıf (opsiyonel ama kullanışlı)
@immutable
class GeoPoint {
  final double longitude;
  final double latitude;
  const GeoPoint({required this.longitude, required this.latitude});

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    // Koordinat listesinin varlığını ve tipini kontrol et
    final coords = json['coordinates'];
    if (coords == null || coords is! List || coords.length < 2) {
      throw FormatException("GeoPoint JSON'da geçersiz 'coordinates': $json");
    }
    // Elemanların double olup olmadığını kontrol et (veya tryParse kullan)
    final lon = coords[0];
    final lat = coords[1];
    if (lon is! num || lat is! num) {
      throw FormatException("GeoPoint JSON'da geçersiz koordinat tipi: $json");
    }
    return GeoPoint(longitude: lon.toDouble(), latitude: lat.toDouble());
  }
}

@immutable
class Field {
  final String id;
  final String name;
  final String? address;
  final GeoPoint? location; // GeoJSON Point olarak alalım
  final bool hasShowers;
  final bool isIndoor;
  final double communityRating;
  final DateTime createdAt;

  const Field({
    required this.id,
    required this.name,
    this.address,
    this.location,
    required this.hasShowers,
    required this.isIndoor,
    required this.communityRating,
    required this.createdAt,
  });

  // --- GÜNCELLENMİŞ fromJson ---
  factory Field.fromJson(Map<String, dynamic> json) {
    // Zorunlu alanları nullable olarak al
    final String? id = json['id'] as String?;
    final String? name = json['name'] as String?;
    final String? createdAtStr = json['created_at'] as String?;
    // Location zorunlu ama null gelebilir mi diye kontrol edelim
    final dynamic locationJson = json['location'];

    // Zorunlu alanlar eksikse hata fırlat
    if (id == null ||
        name == null ||
        createdAtStr == null ||
        locationJson == null) {
      throw FormatException(
        "Field JSON'dan zorunlu alan eksik veya null: $json",
      );
    }

    // Konumu güvenli bir şekilde parse et
    GeoPoint? parsedLocation;
    if (locationJson is Map<String, dynamic>) {
      try {
        parsedLocation = GeoPoint.fromJson(locationJson);
      } catch (e) {
        // Hatalı location verisini logla ama devam et (veya hata fırlatılabilir)
        debugPrint(
          "Field JSON'da geçersiz location verisi: $locationJson, Hata: $e",
        );
        // throw FormatException("Field JSON'da geçersiz location verisi: $locationJson"); // Daha katı olabilir
      }
    } else {
      throw FormatException("Field JSON'da location Map değil: $locationJson");
    }
    // Location parse edilemediyse hata fırlat (çünkü zorunlu kabul ettik)
    if (parsedLocation == null) {
      throw FormatException("Field JSON'dan location parse edilemedi: $json");
    }

    // Tarihi güvenli parse et
    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(createdAtStr);
    } catch (e) {
      throw FormatException(
        "Field JSON'da geçersiz 'created_at' formatı: $createdAtStr",
      );
    }

    // Helper to parse double safely
    double parseDouble(dynamic value) =>
        double.tryParse(value?.toString() ?? '0.0') ?? 0.0;

    return Field(
      id: id,
      name: name,
      address: json['address'] as String?, // Opsiyonel
      location: parsedLocation, // Güvenli parse edilmiş location
      // bool alanlar için null kontrolü ve varsayılan değer
      hasShowers: json['has_showers'] as bool? ?? false,
      isIndoor: json['is_indoor'] as bool? ?? false,
      // double alanı güvenli parse et
      communityRating: parseDouble(json['community_rating']),
      createdAt: createdAt,
    );
  }
}
