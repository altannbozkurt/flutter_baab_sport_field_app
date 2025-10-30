// lib/features/fields/providers/fields_notifier_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart'; // Position için
import 'package:flutter_baab_sport_field_app/core/providers/location_provider.dart'; // Konum için
import 'package:flutter_baab_sport_field_app/features/fields/repositories/field_repository.dart'; // Repository için
import 'package:meta/meta.dart';

// Saha listesinin durumunu tutacak state
@immutable
class FieldsState {
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> fields;

  const FieldsState({
    this.isLoading = true,
    this.errorMessage,
    this.fields = const [],
  });

  FieldsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? fields,
    bool clearError = false,
  }) {
    return FieldsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fields: fields ?? this.fields,
    );
  }
}

// Sahaları yönetecek Notifier
class FieldsNotifier extends StateNotifier<FieldsState> {
  final FieldRepository _fieldRepository;
  final Ref _ref;

  FieldsNotifier(this._fieldRepository, this._ref)
    : super(const FieldsState()) {
    // Konum hazır olduğunda sahaları getir
    // Not: Konum değişirse otomatik yeniden getirmesi için 'listen' kullanabiliriz
    // Ama şimdilik sadece bir kere getirmesi yeterli olabilir.
    _fetchInitialFields();
  }

  Future<void> _fetchInitialFields() async {
    // currentPositionProvider'ın ilk değerini (Future) oku
    try {
      final position = await _ref.read(
        currentPositionProvider.future,
      ); // Future'ın tamamlanmasını bekle
      if (mounted) {
        fetchNearbyFields(position);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Konum alınamadı: $e',
        );
      }
    }
  }

  Future<void> fetchNearbyFields(Position position) async {
    debugPrint(
      '>>> Fetching fields for position: ${position.latitude}, ${position.longitude}',
    );
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final fields = await _fieldRepository.findNearbyFields(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        state = state.copyWith(isLoading: false, fields: fields);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
    }
  }
}

// FieldsNotifier'ı sağlayan Provider
final fieldsNotifierProvider =
    StateNotifierProvider<FieldsNotifier, FieldsState>((ref) {
      final fieldRepository = ref.watch(fieldRepositoryProvider);
      return FieldsNotifier(fieldRepository, ref);
    });
