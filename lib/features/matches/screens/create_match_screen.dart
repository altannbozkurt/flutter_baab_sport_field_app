// lib/features/matches/screens/create_match_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_baab_sport_field_app/features/fields/providers/fields_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/matches_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/create_match_form_provider.dart';

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

// Yeni UI için enum'lar (daha okunaklı)
enum JoinType { open, approval }

enum PrivacyType { public, private }

class CreateMatchScreen extends HookConsumerWidget {
  const CreateMatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Hook'lar
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final notesController = useTextEditingController();
    final currentStep = useState(0); // Stepper için
    final shouldAutovalidate = useState(false); // Hata gösterimi için

    // 2. Provider'lar
    final formState = ref.watch(createMatchFormProvider);
    final formNotifier = ref.read(createMatchFormProvider.notifier);
    final fieldsState = ref.watch(fieldsNotifierProvider);
    final matchesNotifierState = ref.watch(matchesNotifierProvider);

    // 3. GÜNCELLENMİŞ useEffect: UI state'i (currentStep) ile data state'i (formState) senkronize et
    useEffect(() {
      // Bu hook, 'formState' her değiştiğinde çalışır.

      // a) Notları senkronize et
      if (notesController.text != formState.notes) {
        notesController.text = formState.notes;
      }

      // b) Formun sıfırlandığını (reset) algıla ve UI'ı da sıfırla.
      // 'selectedFieldId'nin 'null' olması, formun başında olduğumuz anlamına gelir.
      if (formState.selectedFieldId == null && currentStep.value != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          currentStep.value = 0;
          shouldAutovalidate.value = false;
          formKey.currentState?.reset();
        });
      }
      return null;
    }, [formState]); // Bağımlılık dizisine 'formState' eklendi.

    // 4. GÜNCELLENMİŞ ref.listen: Başarı durumunda SADECE datayı sıfırla
    ref.listen<MatchesState>(matchesNotifierProvider, (previous, next) {
      // Başarılı oluşturma
      if (previous?.isCreating == true &&
          !next.isCreating &&
          next.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Match created successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // SADECE data provider'ı sıfırla.
          // 'useEffect' bloğu, bu değişikliği algılayıp UI'ı (currentStep)
          // otomatik olarak sıfırlayacaktır.
          formNotifier.resetForm();
          notesController.clear();

          context.go('/'); // Ana sayfaya dön
        }
      }
      // Hata oluştuysa
      if (next.errorMessage != null && previous?.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${next.errorMessage!}"),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });

    // 5. Tarih/Saat Seçiciler
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

    Future<void> _selectTime(BuildContext context) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: formState.selectedTime ?? TimeOfDay.now(),
      );
      if (picked != null) {
        formNotifier.updateTime(picked);
      }
    }

    // 6. Form Gönderme
    void submitCreateMatch() async {
      if (matchesNotifierState.isCreating ||
          !(formKey.currentState?.validate() ?? false)) {
        shouldAutovalidate.value = true;
        formKey.currentState?.validate();
        return;
      }

      final fieldId = formState.selectedFieldId;
      final date = formState.selectedDate;
      final time = formState.selectedTime;

      if (fieldId == null || date == null || time == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill out all required fields.')),
        );
        return;
      }

      final DateTime combinedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      final String startTimeIso = combinedDateTime.toUtc().toIso8601String();

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
    }

    // --- Adım 1 İçeriği ---
    Widget _buildStep1Content() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fieldsState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (fieldsState.errorMessage != null)
            Text(
              'Could not load fields: ${fieldsState.errorMessage}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('field_${formState.selectedFieldId ?? 'null'}'),
              value: formState.selectedFieldId,
              hint: const Text('Select a Field *'),
              decoration: const InputDecoration(
                labelText: 'Field',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
              items: fieldsState.fields
                  .map((field) {
                    final fieldIdFromServer = field['id'];
                    if (fieldIdFromServer == null) return null;
                    return DropdownMenuItem<String>(
                      value: fieldIdFromServer.toString(),
                      child: Text(field['name'] ?? 'Unnamed Field'),
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
                  value == null ? 'Please select a field' : null,
              autovalidateMode: shouldAutovalidate.value
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  // Controller'ı bu şekilde ayarlamak, form sıfırlandığında
                  // text'in de sıfırlanmasını sağlar.
                  controller: TextEditingController(
                    text: formState.selectedDate == null
                        ? ''
                        : DateFormat(
                            'EEE, MMM d, yyyy',
                          ).format(formState.selectedDate!),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Date *',
                    hintText: 'Select Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: matchesNotifierState.isCreating
                      ? null
                      : () => _selectDate(context),
                  validator: (_) =>
                      formState.selectedDate == null ? 'Required' : null,
                  autovalidateMode: shouldAutovalidate.value
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: formState.selectedTime == null
                        ? ''
                        : MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(formState.selectedTime!),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Time *',
                    hintText: 'Select Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  onTap: matchesNotifierState.isCreating
                      ? null
                      : () => _selectTime(context),
                  validator: (_) =>
                      formState.selectedTime == null ? 'Required' : null,
                  autovalidateMode: shouldAutovalidate.value
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // --- Adım 2 İçeriği ---
    Widget _buildStep2Content() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match Format *',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: matchFormats.map((format) {
              return ChoiceChip(
                label: Text(format),
                selected: formState.selectedFormat == format,
                onSelected: matchesNotifierState.isCreating
                    ? null
                    : (bool selected) {
                        if (selected) {
                          formNotifier.updateFormat(format);
                        }
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Duration (minutes) *',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: matchDurations.map((duration) {
              return ButtonSegment<int>(
                value: duration,
                label: Text('$duration min'),
              );
            }).toList(),
            selected: {formState.selectedDuration},
            onSelectionChanged: (Set<int> newSelection) {
              if (!matchesNotifierState.isCreating) {
                formNotifier.updateDuration(newSelection.first);
              }
            },
            showSelectedIcon: false,
          ),
        ],
      );
    }

    // --- Adım 3 İçeriği ---
    Widget _buildStep3Content() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Join Type *', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<JoinType>(
            segments: const [
              ButtonSegment<JoinType>(
                value: JoinType.open,
                label: Text('Open Join'),
                icon: Icon(Icons.lock_open_outlined),
              ),
              ButtonSegment<JoinType>(
                value: JoinType.approval,
                label: Text('Approval'),
                icon: Icon(Icons.lock_outline),
              ),
            ],
            selected: {
              formState.selectedJoinType == 'open'
                  ? JoinType.open
                  : JoinType.approval,
            },
            onSelectionChanged: (Set<JoinType> newSelection) {
              if (!matchesNotifierState.isCreating) {
                formNotifier.updateJoinType(
                  newSelection.first == JoinType.open
                      ? 'open'
                      : 'approval_required',
                );
              }
            },
          ),
          const SizedBox(height: 24),
          Text('Privacy *', style: Theme.of(context).textTheme.titleMedium),
          ...PrivacyType.values.map((option) {
            return RadioListTile<PrivacyType>(
              title: Text(option == PrivacyType.public ? 'Public' : 'Private'),
              subtitle: Text(
                option == PrivacyType.public
                    ? 'Visible to everyone nearby'
                    : 'Only visible to invited players',
              ),
              value: option,
              groupValue: formState.selectedPrivacy == 'public'
                  ? PrivacyType.public
                  : PrivacyType.private,
              onChanged: matchesNotifierState.isCreating
                  ? null
                  : (PrivacyType? value) {
                      if (value != null) {
                        formNotifier.updatePrivacy(
                          value == PrivacyType.public ? 'public' : 'private',
                        );
                      }
                    },
            );
          }).toList(),
          const SizedBox(height: 24),
          TextFormField(
            key: ValueKey('notes_${formState.notes}'),
            controller: notesController,
            decoration: const InputDecoration(
              labelText: 'Match Notes (Optional)',
              border: OutlineInputBorder(),
              hintText: 'e.g., Bring a white and dark shirt.',
            ),
            maxLines: 3,
            enabled: !matchesNotifierState.isCreating,
            onChanged: (value) => formNotifier.updateNotes(value),
          ),
        ],
      );
    }

    // --- Stepper Adımları ---
    final steps = [
      Step(
        title: const Text('Where & When'),
        content: _buildStep1Content(),
        isActive: currentStep.value >= 0,
        state:
            (shouldAutovalidate.value &&
                (formState.selectedFieldId == null ||
                    formState.selectedDate == null ||
                    formState.selectedTime == null))
            ? StepState.error
            : (currentStep.value > 0 ? StepState.complete : StepState.editing),
      ),
      Step(
        title: const Text('Details'),
        content: _buildStep2Content(),
        isActive: currentStep.value >= 1,
        state: currentStep.value > 1 ? StepState.complete : StepState.editing,
      ),
      Step(
        title: const Text('Settings & Notes'),
        content: _buildStep3Content(),
        isActive: currentStep.value >= 2,
        state: currentStep.value > 2 ? StepState.complete : StepState.editing,
      ),
    ];

    // 8. Ana Arayüz (UI)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Form',
            onPressed: matchesNotifierState.isCreating
                ? null
                : () {
                    formNotifier.resetForm();
                    notesController.clear();
                    // formKey.currentState?.reset(); // useEffect halledecek
                    // shouldAutovalidate.value = false; // useEffect halledecek
                    // currentStep.value = 0; // useEffect halledecek
                  },
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: currentStep.value,
          onStepTapped: (step) {
            if (matchesNotifierState.isCreating) return;
            if (step < currentStep.value) {
              currentStep.value = step;
              return;
            }
            if (formKey.currentState?.validate() ?? false) {
              currentStep.value = step;
            } else {
              shouldAutovalidate.value = true;
              formKey.currentState?.validate();
            }
          },
          onStepContinue: () {
            if (matchesNotifierState.isCreating) return;

            if (!(formKey.currentState?.validate() ?? false)) {
              shouldAutovalidate.value = true;
              formKey.currentState?.validate();
              return;
            }

            if (currentStep.value == steps.length - 1) {
              submitCreateMatch();
            } else {
              currentStep.value += 1;
            }
          },
          onStepCancel: () {
            if (matchesNotifierState.isCreating) return;
            if (currentStep.value > 0) {
              currentStep.value -= 1;
            }
          },
          controlsBuilder: (BuildContext context, ControlsDetails details) {
            final bool isLastStep = currentStep.value == steps.length - 1;
            return Container(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: <Widget>[
                  if (matchesNotifierState.isCreating && isLastStep)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(isLastStep ? 'Create Match' : 'Continue'),
                    ),

                  const SizedBox(width: 12),

                  if (currentStep.value > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: matchesNotifierState.isCreating
                          ? const SizedBox.shrink()
                          : const Text('Back'),
                    ),
                ],
              ),
            );
          },
          steps: steps,
        ),
      ),
    );
  }
}

// Helper for copyWith nullable workaround
typedef ValueGetter<T> = T Function();
