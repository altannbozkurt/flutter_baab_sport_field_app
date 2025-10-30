import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_baab_sport_field_app/models/match_participant.dart';
import 'package:flutter_baab_sport_field_app/features/votes/providers/votes_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/models/user.dart';
import 'package:collection/collection.dart'; // firstWhereOrNull için

// MatchDetailScreen'den 'availableTags' listesini buraya taşıyalım
const Map<String, String> availableTags = {
  'FINISHING': '⚽ Bitiricilik',
  'DEFENDING': '🧱 Kritik Müdahale',
  'PASSING': '🎯 Kilit Pas',
  'DRIBBLING': '⚡ Çalım Yeteneği',
  'TEAM_PLAYER': '🔋 Takım Motoru',
  'FAIR_PLAY': '🤝 Centilmenlik',
};

class MatchVotingWidget extends HookConsumerWidget {
  final String matchId;
  final List<MatchParticipant> otherPlayers; // Kendimiz dışındaki oyuncular

  const MatchVotingWidget({
    required this.matchId,
    required this.otherPlayers,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Lokal Form State'leri (Hook kullanarak)
    // Oylama için seçilen değerleri tutar
    final selectedMvpUserId = useState<String?>(null);
    final selectedPlayerForTagId = useState<String?>(null);
    final selectedTagId = useState<String?>(null);

    // 2. Global Oylama State'i (Yükleniyor, Hata, Oy Kullanıldı mı?)
    final votesState = ref.watch(votesNotifierProvider);
    final votesNotifier = ref.read(votesNotifierProvider.notifier);

    // 3. Oyları Gönderme Fonksiyonu
    void submitVotes() async {
      // Sadece MVP veya (Etiket+Oyuncu)'dan en az biri seçiliyse gönder
      if (selectedMvpUserId.value == null &&
          (selectedPlayerForTagId.value == null ||
              selectedTagId.value == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen MVP veya Etiket oylaması yapın.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Etiket seçildi ama oyuncu seçilmediyse (gerçi UI bunu engellemeli)
      if (selectedTagId.value != null && selectedPlayerForTagId.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Etiket için lütfen bir oyuncu seçin.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      bool mvpSuccess = true;
      bool tagSuccess = true;

      // MVP Oyu Gönder
      if (selectedMvpUserId.value != null && !votesState.hasVotedMvp) {
        mvpSuccess = await votesNotifier.submitMvpVote(
          matchId: matchId,
          votedUserId: selectedMvpUserId.value!,
        );
      }

      // Etiket Oyu Gönder
      if (selectedPlayerForTagId.value != null &&
          selectedTagId.value != null &&
          !votesState.hasVotedTag) {
        tagSuccess = await votesNotifier.submitTagVote(
          matchId: matchId,
          taggedUserId: selectedPlayerForTagId.value!,
          tagId: selectedTagId.value!,
        );
      }

      // Genel Başarı (Hata mesajları zaten Notifier/Listener tarafından gösterilecek)
      if (mvpSuccess && tagSuccess && context.mounted) {
        // Başarı SnackBar'ı zaten MatchDetailScreen'deki ref.listen'de gösteriliyor.
        debugPrint("Oylama(lar) başarıyla gönderildi.");
      }
    }

    // --- UI Kısmı ---

    // Oylama bittiyse (veya zaten yapmışsa) "Teşekkürler" mesajı göster
    // TODO: Backend'den 'zaten oy kullanıldı' bilgisini çekip
    // bu state'i (hasVotedMvp/Tag) doldurmak gerekir.
    // Şimdilik sadece bu oturumda oy kullandıysa teşekkür et.
    if (votesState.hasVotedMvp && votesState.hasVotedTag) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Text(
                  'Oylarını kullandığın için teşekkürler!',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Oylama formu
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maç Sonu Oylama',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // --- MVP SEÇİMİ (RadioListTile) ---
            if (!votesState.hasVotedMvp) ...[
              // Henüz MVP oyu kullanmadıysa
              Text(
                'Maçın Oyuncusu (MVP):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Kaydırılabilir liste (çok oyuncu varsa)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                height: 180, // Yüksekliği kısıtla
                child: ListView(
                  shrinkWrap: true,
                  children: otherPlayers.map((p) {
                    final user = p.user!;
                    return RadioListTile<String>(
                      title: Text(user.fullName),
                      value: user.id,
                      groupValue: selectedMvpUserId.value,
                      secondary: CircleAvatar(
                        radius: 15,
                        backgroundImage: user.displayImageUrl.startsWith('http')
                            ? NetworkImage(user.displayImageUrl)
                            : AssetImage(user.displayImageUrl) as ImageProvider,
                      ),
                      onChanged: votesState.isSubmitting
                          ? null
                          : (value) {
                              selectedMvpUserId.value = value;
                            },
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 24),
            ] else ...[
              // Zaten oy kullanmış
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  'MVP Oyu Kullanıldı',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              const Divider(height: 24),
            ],

            // --- ETİKET SEÇİMİ (İki Adımlı) ---
            if (!votesState.hasVotedTag) ...[
              // Henüz Etiket oyu kullanmadıysa
              Text(
                'Öne Çıkan Performans (1 Etiket):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Adım A: Oyuncu Seç
              DropdownButtonFormField<String?>(
                value: selectedPlayerForTagId.value,
                hint: const Text('Önce oyuncu seçin...'),
                decoration: const InputDecoration(
                  labelText: 'Oyuncu',
                  border: OutlineInputBorder(),
                ),
                items: otherPlayers.map((p) {
                  return DropdownMenuItem<String?>(
                    value: p.userId,
                    child: Text(p.user?.fullName ?? 'Bilinmeyen'),
                  );
                }).toList(),
                onChanged: votesState.isSubmitting
                    ? null
                    : (value) {
                        selectedPlayerForTagId.value = value;
                        selectedTagId.value =
                            null; // Oyuncu değiştiğinde etiketi sıfırla
                      },
              ),
              const SizedBox(height: 16),

              // Adım B: Etiket Seç (Eğer oyuncu seçildiyse)
              // Animasyonlu görünüm
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: (selectedPlayerForTagId.value != null)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${otherPlayers.firstWhereOrNull((p) => p.userId == selectedPlayerForTagId.value)?.user?.fullName ?? ''} için bir etiket seç:',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: availableTags.entries.map((entry) {
                              final tagId = entry.key;
                              final tagName = entry.value;
                              return ChoiceChip(
                                label: Text(tagName),
                                selected: selectedTagId.value == tagId,
                                onSelected: votesState.isSubmitting
                                    ? null
                                    : (isSelected) {
                                        if (isSelected) {
                                          selectedTagId.value = tagId;
                                        }
                                      },
                                selectedColor: Colors.green.withOpacity(0.3),
                              );
                            }).toList(),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(), // Oyuncu seçilmediyse boş
              ),
              const Divider(height: 24),
            ] else ...[
              // Zaten oy kullanmış
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  'Etiket Oyu Kullanıldı',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              const Divider(height: 24),
            ],

            // --- OYLARI GÖNDER BUTONU ---
            // Oylanmamış en az bir şey varsa (veya state'te oy kullanıldı bilgisi yoksa) butonu göster
            if (!votesState.hasVotedMvp || !votesState.hasVotedTag)
              Center(
                child: votesState.isSubmitting
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Oyları Gönder'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        // Sadece en az bir seçim yapıldıysa aktifleştir
                        onPressed:
                            (selectedMvpUserId.value != null ||
                                (selectedPlayerForTagId.value != null &&
                                    selectedTagId.value != null))
                            ? submitVotes
                            : null,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
