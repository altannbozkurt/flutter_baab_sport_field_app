// lib/features/lobby/screens/create_lobby_post_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_baab_sport_field_app/features/fields/providers/fields_notifier_provider.dart';

import 'package:flutter_baab_sport_field_app/features/lobby/providers/lobby_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/models/field.dart';

class CreateLobbyPostScreen extends HookConsumerWidget {
  const CreateLobbyPostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Form Key
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Form Controllers
    final titleController = useTextEditingController();
    final descController = useTextEditingController();
    final playersNeededController = useTextEditingController(text: '1');
    final positionController = useTextEditingController();

    // Form State
    final postType = useState(
      'PLAYER_WANTED',
    ); // PLAYER_WANTED | OPPONENT_WANTED
    final teamSize = useState(7); // 7v7, 6v6 etc.
    final selectedField = useState<Field?>(null);
    final selectedDateTime = useState<DateTime?>(null);

    // Form gönderim (submission) state'ini izle
    final lobbyState = ref.watch(lobbyNotifierProvider);

    // Formu gönderen metot
    void submitPost() async {
      // 1. Form geçerli mi?
      if (formKey.currentState?.validate() != true) return;
      // 2. Tarih seçildi mi?
      if (selectedDateTime.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a match time.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 3. Notifier'ı çağır
      final success = await ref
          .read(lobbyNotifierProvider.notifier)
          .createPost(
            title: titleController.text,
            description: descController.text.isEmpty
                ? null
                : descController.text,
            type: postType.value,
            fieldId: selectedField.value?.id,
            matchTime: selectedDateTime.value!,
            teamSize: teamSize.value,
            playersNeeded: postType.value == 'PLAYER_WANTED'
                ? int.tryParse(playersNeededController.text)
                : null,
            positionNeeded: postType.value == 'PLAYER_WANTED'
                ? positionController.text.isEmpty
                      ? null
                      : positionController.text
                : null,
          );

      if (success && context.mounted) {
        // Formu temizle
        formKey.currentState?.reset();
        titleController.clear();
        descController.clear();
        playersNeededController.text = '1';
        positionController.clear();
        postType.value = 'PLAYER_WANTED';
        teamSize.value = 7;
        selectedField.value = null;
        selectedDateTime.value = null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lobby post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Eğer geri gidecek sayfa yoksa ana sayfaya yönlendir
        if (context.canPop()) {
          context.pop(); // Formu kapat
        } else {
          context.go('/'); // Home'a git
        }
      }
    }

    // Yakındaki sahaları getir (Dropdown için)
    final fieldsAsync = ref.watch(nearbyFieldsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Lobby Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. İlan Türü Seçimi
              Text(
                'I am looking for a...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'PLAYER_WANTED',
                    label: Text('Player'),
                    icon: Icon(Icons.person_add),
                  ),
                  ButtonSegment(
                    value: 'OPPONENT_WANTED',
                    label: Text('Opponent'),
                    icon: Icon(Icons.group_add),
                  ),
                ],
                selected: {postType.value},
                onSelectionChanged: (newSelection) {
                  postType.value = newSelection.first;
                },
              ),
              const SizedBox(height: 20),

              // 2. Başlık
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., "Goalie needed for Tuesday game"',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),

              // 3. Açıklama
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g., "Advanced level game, please be on time."',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // 4. Saha ve Zaman
              Row(
                children: [
                  // Saha Seçimi
                  Expanded(
                    child: fieldsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, s) => const Text('Fields error'),
                      data: (fields) => DropdownButtonFormField<Field>(
                        value: selectedField.value,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Field (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: fields
                            .map(
                              (field) => DropdownMenuItem(
                                value: field,
                                child: Text(
                                  field.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (field) {
                          selectedField.value = field;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Zaman Seçimi
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Match Time',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                        hintText: selectedDateTime.value == null
                            ? 'Select time'
                            : DateFormat(
                                'MMM d, h:mm a',
                                'en_US',
                              ).format(selectedDateTime.value!.toLocal()),
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final newDate = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 30)),
                        );
                        if (newDate == null || !context.mounted) return;

                        final newTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(now),
                        );
                        if (newTime == null) return;

                        selectedDateTime.value = DateTime(
                          newDate.year,
                          newDate.month,
                          newDate.day,
                          newTime.hour,
                          newTime.minute,
                        );
                      },
                      validator: (value) =>
                          selectedDateTime.value == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Format ve İhtiyaç
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: teamSize.value,
                      decoration: const InputDecoration(
                        labelText: 'Format',
                        border: OutlineInputBorder(),
                      ),
                      items: [5, 6, 7, 8, 9, 10, 11]
                          .map(
                            (size) => DropdownMenuItem(
                              value: size,
                              child: Text('${size}v$size'),
                            ),
                          )
                          .toList(),
                      onChanged: (size) {
                        if (size != null) teamSize.value = size;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Koşullu Alanlar (Sadece Oyuncu Aranıyorsa)
                  if (postType.value == 'PLAYER_WANTED')
                    Expanded(
                      child: TextFormField(
                        controller: playersNeededController,
                        decoration: const InputDecoration(
                          labelText: 'Players Needed',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Invalid num';
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),

              // 6. Pozisyon (Sadece Oyuncu Aranıyorsa)
              if (postType.value == 'PLAYER_WANTED') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: positionController,
                  decoration: const InputDecoration(
                    labelText: 'Position Needed (Optional)',
                    hintText: 'e.g., Goalkeeper, Defender',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // 7. Gönder Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: lobbyState.isLoading ? null : submitPost,
                  icon: lobbyState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign),
                  label: Text(
                    lobbyState.isLoading ? 'Posting...' : 'Create Post',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (lobbyState.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Error: ${lobbyState.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
