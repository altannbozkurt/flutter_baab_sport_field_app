// lib/features/matches/providers/create_match_form_provider.dart
import 'package:flutter/material.dart'; // TimeOfDay için
import 'package:flutter_riverpod/legacy.dart';
import 'package:meta/meta.dart';

@immutable
class CreateMatchFormState {
  final String? selectedFieldId;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final int selectedDuration;
  final String selectedFormat;
  final String selectedPrivacy;
  final String selectedJoinType;
  final String notes;

  // Başlangıç değerleri
  const CreateMatchFormState({
    this.selectedFieldId,
    this.selectedDate,
    this.selectedTime,
    this.selectedDuration = 60, // default duration in minutes
    this.selectedFormat = '7v7', // default format
    this.selectedPrivacy = 'public', // default privacy
    this.selectedJoinType = 'open', // default join type
    this.notes = '',
  });

  // Kopyalama metodu
  CreateMatchFormState copyWith({
    // Value assignment workaround for nullable types
    ValueGetter<String?>? selectedFieldId,
    ValueGetter<DateTime?>? selectedDate,
    ValueGetter<TimeOfDay?>? selectedTime,
    int? selectedDuration,
    String? selectedFormat,
    String? selectedPrivacy,
    String? selectedJoinType,
    String? notes,
  }) {
    return CreateMatchFormState(
      // Use call() to get value or keep existing if null
      selectedFieldId: selectedFieldId != null
          ? selectedFieldId()
          : this.selectedFieldId,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      selectedTime: selectedTime != null ? selectedTime() : this.selectedTime,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      selectedPrivacy: selectedPrivacy ?? this.selectedPrivacy,
      selectedJoinType: selectedJoinType ?? this.selectedJoinType,
      notes: notes ?? this.notes,
    );
  }
}

// Form state'ini yönetecek Notifier
class CreateMatchFormNotifier extends StateNotifier<CreateMatchFormState> {
  CreateMatchFormNotifier()
    : super(const CreateMatchFormState()); // Başlangıç state'i

  // Alanları güncelleyen metotlar
  void updateFieldId(String? value) =>
      state = state.copyWith(selectedFieldId: () => value);
  void updateDate(DateTime? value) =>
      state = state.copyWith(selectedDate: () => value);
  void updateTime(TimeOfDay? value) =>
      state = state.copyWith(selectedTime: () => value);
  void updateDuration(int? value) =>
      state = state.copyWith(selectedDuration: value);
  void updateFormat(String? value) =>
      state = state.copyWith(selectedFormat: value);
  void updatePrivacy(String? value) =>
      state = state.copyWith(selectedPrivacy: value);
  void updateJoinType(String? value) =>
      state = state.copyWith(selectedJoinType: value);
  void updateNotes(String value) => state = state.copyWith(notes: value);

  // Formu sıfırlayan metot
  void resetForm() {
    state = const CreateMatchFormState(); // Başlangıç state'ine geri dön
  }
}

// Bu Notifier'ı sağlayan Provider
final createMatchFormProvider =
    StateNotifierProvider<CreateMatchFormNotifier, CreateMatchFormState>((ref) {
      return CreateMatchFormNotifier();
    });
