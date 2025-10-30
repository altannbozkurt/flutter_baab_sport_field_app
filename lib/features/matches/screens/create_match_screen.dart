// lib/features/matches/screens/create_match_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_baab_sport_field_app/features/fields/providers/fields_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/matches_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/create_match_form_provider.dart'; // <-- YENİ FORM PROVIDER

// Sabit listeler
const List<String> matchFormats = [
  '5v5',
  '6v6',
  '7v7',
  '8v8',
  '9v9',
  '10v10',
  '11v11',
];
const List<int> matchDurations = [60, 90, 120];
const List<String> privacyOptions = ['public', 'private'];
const List<String> joinOptions = ['open', 'approval_required'];

class CreateMatchScreen extends HookConsumerWidget {
  const CreateMatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Form anahtarı ve Controller'lar (Hook ile)
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final notesController = useTextEditingController();
    final dateController = useTextEditingController();
    final timeController = useTextEditingController();
    final shouldAutovalidate = useState<bool>(false);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        formKey.currentState
            ?.reset(); // tüm validator/error görünümlerini sıfırlar
      });
      return null;
    }, const []);

    // 2. Form state'ini ve notifier'ını Riverpod'dan al
    final formState = ref.watch(createMatchFormProvider);
    final formNotifier = ref.read(createMatchFormProvider.notifier);

    // 3. Diğer state'leri dinle
    final fieldsState = ref.watch(fieldsNotifierProvider);
    final matchesNotifierState = ref.watch(matchesNotifierProvider);

    // 4. Başarı/Hata SnackBar'ları ve Yönlendirme + Form Sıfırlama
    ref.listen<MatchesState>(matchesNotifierProvider, (previous, next) {
      // Başarılı oluşturma
      if (previous?.isCreating == true &&
          !next.isCreating &&
          next.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maç başarıyla oluşturuldu!'),
              backgroundColor: Colors.green,
            ),
          );
          // BAŞARILI OLDUĞUNDA FORMU SIFIRLA!
          formNotifier.resetForm();
          notesController.clear(); // Controller'ı da temizle
          shouldAutovalidate.value = false; // uyarıları kapat
          context.go('/'); // Ana sayfaya dön
        }
      }
      // Hata oluştuysa
      if (next.errorMessage != null && previous?.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Hata: ${next.errorMessage!}"),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });

    // 5. Tarih seçici (formNotifier'ı kullanacak)
    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: formState.selectedDate ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 90)),
      );
      if (picked != null) {
        formNotifier.updateDate(picked);
      }
    }

    // 6. Saat seçici (formNotifier'ı kullanacak)
    Future<void> _selectTime(BuildContext context) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: formState.selectedTime ?? TimeOfDay.now(),
      );
      if (picked != null) {
        formNotifier.updateTime(picked);
      }
    }

    // 7. Formu gönderme (formState'i kullanacak)
    void submitCreateMatch() async {
      // Yükleniyorsa veya form geçersizse bir şey yapma
      if (matchesNotifierState.isCreating ||
          !(formKey.currentState?.validate() ?? false)) {
        // Form geçerli değilse uyarıları görünür yap
        shouldAutovalidate.value = true;
        formKey.currentState?.validate(); // Tüm validator'ları tetikle
        return;
      }

      final fieldId = formState.selectedFieldId;
      final date = formState.selectedDate;
      final time = formState.selectedTime;

      // Validator'lar null olmasını engeller, bu kontrol gereksiz olabilir ama kalsın.
      if (fieldId == null || date == null || time == null) return;

      final DateTime combinedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      // Sunucu tarafında tutarlılık için UTC gönder
      final String startTimeIso = combinedDateTime.toUtc().toIso8601String();

      // Notifier'ı çağır
      await ref
          .read(matchesNotifierProvider.notifier)
          .createMatch(
            fieldId: fieldId,
            startTimeIso: startTimeIso,
            durationMinutes: formState.selectedDuration,
            format: formState.selectedFormat,
            privacyType: formState.selectedPrivacy,
            joinType: formState.selectedJoinType,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );
      // Başarı/Hata yönetimi ve yönlendirme artık ref.listen içinde
    }

    // Controller'ları formState ile senkronize tut (inherited erişimleri post-frame'de yap)
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Notes
        if (notesController.text != formState.notes) {
          notesController.text = formState.notes;
        }
        // Date (inherited gerektirmez ama tutarlılık için aynı blokta)
        final dateText = formState.selectedDate == null
            ? ''
            : DateFormat('yyyy-MM-dd').format(formState.selectedDate!);
        if (dateController.text != dateText) {
          dateController.text = dateText;
        }
        // Time (MaterialLocalizations.of(context) => inherited, bu yüzden post-frame)
        final timeText = formState.selectedTime == null
            ? ''
            : MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(formState.selectedTime!);
        if (timeController.text != timeText) {
          timeController.text = timeText;
        }
      });
      return null;
    }, [formState.notes, formState.selectedDate, formState.selectedTime]);

    // 8. Arayüz (UI)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Maç Oluştur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Formu Sıfırla',
            onPressed: matchesNotifierState.isCreating
                ? null
                : () {
                    formNotifier.resetForm();
                    notesController.clear();
                    // Formu sıfırladıktan sonra validation'ı da sıfırlayalım
                    formKey.currentState?.reset();
                    shouldAutovalidate.value = false; // uyarıları kapat
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Saha Seçimi ---
              if (fieldsState.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (fieldsState.errorMessage != null)
                Padding(
                  // Hata mesajı için biraz boşluk
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Sahalar yüklenemedi: ${fieldsState.errorMessage}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else if (fieldsState.fields.isEmpty)
                const Padding(
                  // Mesaj için biraz boşluk
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Yakınınızda saha bulunamadı. Lütfen önce bir saha ekleyin.',
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('field_${formState.selectedFieldId ?? 'null'}'),
                  initialValue: formState.selectedFieldId,
                  hint: const Text('Saha Seçin *'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: fieldsState.fields
                      .map((field) {
                        final fieldIdFromServer = field['id'];
                        if (fieldIdFromServer == null) return null;
                        return DropdownMenuItem<String>(
                          value: fieldIdFromServer.toString(),
                          child: Text(field['name'] ?? 'İsimsiz Saha'),
                        );
                      })
                      .whereType<DropdownMenuItem<String>>()
                      .toList(),
                  onChanged: matchesNotifierState.isCreating
                      ? null
                      : (String? newValue) {
                          formNotifier.updateFieldId(newValue);
                        },
                  validator: (value) =>
                      value == null ? 'Lütfen bir saha seçin' : null,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              const SizedBox(height: 16),

              // --- Tarih Seçimi ---
              TextFormField(
                readOnly: true,
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Tarih *',
                  hintText: 'Tarih Seçin',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: matchesNotifierState.isCreating
                    ? null
                    : () {
                        shouldAutovalidate.value = true; // etkileşim başladı
                        _selectDate(context);
                      },
                validator: (_) => formState.selectedDate == null
                    ? 'Lütfen tarih seçin'
                    : null,
                autovalidateMode: shouldAutovalidate.value
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
              ),
              const SizedBox(height: 16),

              // --- Saat Seçimi ---
              TextFormField(
                readOnly: true,
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Saat *',
                  hintText: 'Saat Seçin',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                onTap: matchesNotifierState.isCreating
                    ? null
                    : () {
                        shouldAutovalidate.value = true; // etkileşim başladı
                        _selectTime(context);
                      },
                validator: (_) =>
                    formState.selectedTime == null ? 'Lütfen saat seçin' : null,
                autovalidateMode: shouldAutovalidate.value
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
              ),
              const SizedBox(height: 16),

              // --- Süre Seçimi ---
              DropdownButtonFormField<int>(
                key: ValueKey('duration_${formState.selectedDuration}'),
                initialValue: formState.selectedDuration,
                decoration: const InputDecoration(
                  labelText: 'Süre *',
                  border: OutlineInputBorder(),
                ),
                items: matchDurations.map((duration) {
                  return DropdownMenuItem<int>(
                    value: duration,
                    child: Text('$duration dakika'),
                  );
                }).toList(),
                onChanged: matchesNotifierState.isCreating
                    ? null
                    : (int? newValue) {
                        if (newValue != null)
                          formNotifier.updateDuration(newValue);
                      },
              ),
              const SizedBox(height: 16),

              // --- Format Seçimi ---
              DropdownButtonFormField<String>(
                key: ValueKey('format_${formState.selectedFormat}'),
                initialValue: formState.selectedFormat,
                decoration: const InputDecoration(
                  labelText: 'Format *',
                  border: OutlineInputBorder(),
                ),
                items: matchFormats.map((format) {
                  return DropdownMenuItem<String>(
                    value: format,
                    child: Text(format),
                  );
                }).toList(),
                onChanged: matchesNotifierState.isCreating
                    ? null
                    : (String? newValue) {
                        if (newValue != null)
                          formNotifier.updateFormat(newValue);
                      },
              ),
              const SizedBox(height: 16),

              // --- Gizlilik Seçimi ---
              DropdownButtonFormField<String>(
                key: ValueKey('privacy_${formState.selectedPrivacy}'),
                initialValue: formState.selectedPrivacy,
                decoration: const InputDecoration(
                  labelText: 'Gizlilik',
                  border: OutlineInputBorder(),
                ),
                items: privacyOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option == 'public' ? 'Herkese Açık' : 'Sadece Davetliler',
                    ),
                  );
                }).toList(),
                onChanged: matchesNotifierState.isCreating
                    ? null
                    : (String? newValue) {
                        if (newValue != null)
                          formNotifier.updatePrivacy(newValue);
                      },
              ),
              const SizedBox(height: 16),

              // --- Katılım Türü Seçimi ---
              DropdownButtonFormField<String>(
                key: ValueKey('joinType_${formState.selectedJoinType}'),
                initialValue: formState.selectedJoinType,
                decoration: const InputDecoration(
                  labelText: 'Katılım Türü',
                  border: OutlineInputBorder(),
                ),
                items: joinOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option == 'open' ? 'Hızlı Katılım' : 'Onay Gerekli',
                    ),
                  );
                }).toList(),
                onChanged: matchesNotifierState.isCreating
                    ? null
                    : (String? newValue) {
                        if (newValue != null)
                          formNotifier.updateJoinType(newValue);
                      },
              ),
              const SizedBox(height: 16),

              // --- Maç Notları ---
              TextFormField(
                key: ValueKey('notes_${formState.notes}'),
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Maç Notları (Opsiyonel)',
                  border: OutlineInputBorder(),
                  hintText: 'Örn: Beyaz ve siyah forma getirin.',
                ),
                maxLines: 3,
                enabled: !matchesNotifierState.isCreating,
                onChanged: (value) => formNotifier.updateNotes(value),
              ),
              const SizedBox(height: 24),

              // --- Maçı Oluştur Butonu ---
              if (matchesNotifierState.isCreating)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: matchesNotifierState.isCreating
                      ? null
                      : submitCreateMatch,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Maçı Oluştur'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper for copyWith nullable workaround
typedef ValueGetter<T> = T Function();
