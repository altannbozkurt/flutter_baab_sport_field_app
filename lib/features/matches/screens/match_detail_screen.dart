// lib/features/matches/screens/match_detail_screen.dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/matches_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/widgets/participant_card.dart';
import 'package:flutter_baab_sport_field_app/models/match_participant.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_baab_sport_field_app/models/match.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için
import 'package:flutter_baab_sport_field_app/features/matches/providers/match_detail_provider.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_baab_sport_field_app/features/votes/providers/votes_notifier_provider.dart'; // <-- VOTES NOTIFIER IMPORT
import 'package:flutter_baab_sport_field_app/models/field.dart'; // Field modelini import et
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_baab_sport_field_app/features/matches/widgets/match_voting_widget.dart';

// TODO: Sabit etiket listesini tanımla (belki ayrı bir dosyada)
// const Map<String, String> availableTags = {
//   'FINISHING': '⚽ Bitiricilik',
//   'DEFENDING': '🧱 Kritik Müdahale',
//   'PASSING': '🎯 Kilit Pas',
//   'DRIBBLING': '⚡ Çalım Yeteneği',
//   'TEAM_PLAYER': '🔋 Takım Motoru',
//   'FAIR_PLAY': '🤝 Centilmenlik',
// };

class MatchDetailScreen extends HookConsumerWidget {
  final String matchId;

  const MatchDetailScreen({required this.matchId, super.key});

  // --- YOL TARİFİ İÇİN YARDIMCI FONKSİYON ---
  Future<void> _launchMaps(BuildContext context, Field field) async {
    if (field.location == null) return;

    final lat = field.location!.latitude;
    final lon = field.location!.longitude;
    final query = Uri.encodeComponent(field.address ?? '$lat,$lon');

    Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    Uri appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$query');
    Uri uriToLaunch;

    if (Platform.isIOS) {
      uriToLaunch = appleMapsUrl;
    } else {
      // Android ve diğer platformlar için Google Maps'i dene
      uriToLaunch = googleMapsUrl;
    }

    try {
      if (await canLaunchUrl(uriToLaunch)) {
        await launchUrl(uriToLaunch, mode: LaunchMode.externalApplication);
      } else {
        // Eğer Google/Apple Maps açılmazsa, genel web haritasını aç
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Harita uygulaması açılamadı: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. matchDetailProvider'ı dinle (watch). 'matchId'yi parametre olarak gönder.
    final matchDetailAsyncValue = ref.watch(matchDetailProvider(matchId));
    final matchesNotifierState = ref.watch(
      matchesNotifierProvider,
    ); // Join/Leave isLoading için
    // Giriş yapmış kullanıcının ID'sini al (Auth state'inden)
    // AuthState sınıfına userId eklememiz gerekebilir veya token'dan decode edebiliriz.
    // Şimdilik AuthRepository üzerinden dolaylı yoldan alalım (daha sonra iyileştirilebilir)
    final authState = ref.watch(authNotifierProvider);
    final String? currentUserId = authState.currentUser?.id; // Null olabilir
    final votesState = ref.watch(votesNotifierProvider); // <-- VOTES STATE
    // Kullanıcı veya maç değiştiğinde oy state'ini sıfırla (stale state önlemi)
    useEffect(() {
      // Build sırasında provider'ı değiştirmemek için işlemi bir sonraki frame'e ertele
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final notifier = ref.read(votesNotifierProvider.notifier);
          notifier.reset();
          notifier.fetchMyVoteStatus(matchId);
        }
      });
      return null;
    }, [currentUserId, matchId]);
    // Oylama bölümüne kaydırmak için Key
    final votingSectionKey = useMemoized(() => GlobalKey());
    // --- YENİ: Kaptan yönetimi için lokal state ---
    final processingParticipantId = useState<String?>(null);
    // --- BİTTİ ---
    // --- YENİ: Kaptan katılım onayı için state ---
    // Bu set, kaptanın "gelmedi" olarak işaretlediği KULLANICI ID'lerini tutacak
    final noShowUserIds = useState<Set<String>>({});
    // --- BİTTİ ---

    // --- VotesState İÇİN ref.listen GÜNCELLENDİ (Sadece Hata) ---
    // Başarı SnackBar'ı artık MatchVotingWidget içinde yönetilebilir.
    // Hata mesajını merkezi dinlemek iyidir.
    ref.listen<VotesState>(votesNotifierProvider, (previous, next) {
      if (next.errorMessage != null && previous?.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Oylama Hatası: ${next.errorMessage!}"),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          // Hatayı gösterdikten sonra temizleyelim
          ref.read(votesNotifierProvider.notifier).clearError();
        }
      }

      // (MatchesState listen bloğu aynı kalabilir)
      // ...
    });

    // --- GÜNCELLENMİŞ ref.listen ---
    ref.listen<MatchesState>(matchesNotifierProvider, (previous, next) {
      // Katılımcı Onay/Red
      final bool justFinishedUpdating =
          previous?.isUpdatingParticipant == true &&
          !next.isUpdatingParticipant;
      if (justFinishedUpdating && next.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Katılımcı durumu güncellendi.'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // KAPTAN KATILIM ONAYI (YENİ)
      final bool justFinishedSubmitting =
          previous?.isSubmittingAttendance == true &&
          !next.isSubmittingAttendance;
      if (justFinishedSubmitting) {
        if (context.mounted) {
          if (next.errorMessage == null) {
            // Başarılı
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Katılım listesi onaylandı!'),
                backgroundColor: Colors.green,
              ),
            );
            // Ekran zaten invalidate edildiği için bu bölüm kaybolacak
            // Oylama bölümü varsa yumuşakça kaydır
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = votingSectionKey.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            });
          } else {
            // Hatalı
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Hata: ${next.errorMessage!}"),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }

      // Hata oluştuysa (genel, Kaptan işlemlerini de kapsar)
      if (next.errorMessage != null &&
          previous?.errorMessage == null &&
          (previous?.isUpdatingParticipant == true ||
              previous?.isSubmittingAttendance == true)) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Detayı'),
        // TODO: Kaptansa "Düzenle" veya "İptal Et" butonu eklenebilir
      ),
      body: matchDetailAsyncValue.when(
        // --- Durum 1: Yükleniyor ---
        loading: () => const Center(child: CircularProgressIndicator()),

        // --- Durum 2: Hata ---
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Maç detayları yüklenirken hata oluştu:\n${error.toString().replaceFirst("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  // Provider'ı yenilemeyi dene
                  onPressed: () => ref.refresh(matchDetailProvider(matchId)),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),

        // --- Durum 3: Veri Başarıyla Geldi ---
        data: (match) {
          // Gelen Map verisini parse et (null kontrolleri önemli)
          final field = match.field; // Field nesnesi
          final organizer = match.organizer; // User nesnesi
          final participants =
              match.participants ?? []; // MatchParticipant listesi

          // Katılımcıları ayıralım (kabul edilenler ve bekleyenler)
          final acceptedParticipants = participants
              .where((p) => p.status == 'accepted')
              .toList();
          final requestedParticipants =
              match.participants
                  ?.where((p) => p.status == 'requested')
                  .toList() ??
              []; // Onay bekleyenler

          // --- KAPTAN KONTROLÜ ---
          final bool userIsCaptain = currentUserId == match.organizerId;
          // --- BİTTİ ---

          // --- ZAMAN KONTROLLERİNİ BURADA YAPALIM ---
          final nowUtc = DateTime.now().toUtc();
          final startTimeUtc = match.startTime; // Zaten UTC
          final matchEndTimeUtc = startTimeUtc.add(
            Duration(minutes: match.durationMinutes),
          );
          final voteDeadlineUtc = matchEndTimeUtc.add(
            const Duration(minutes: 60),
          );

          final bool matchHasStarted =
              nowUtc.isAfter(startTimeUtc) ||
              nowUtc.isAtSameMomentAs(startTimeUtc);
          final bool votingWindowOpen =
              nowUtc.isAfter(matchEndTimeUtc) &&
              nowUtc.isBefore(voteDeadlineUtc);
          final bool matchIsOver = nowUtc.isAfter(
            matchEndTimeUtc,
          ); // Maç bitti mi (oylama açık olsa bile)
          final bool votingWindowClosed = nowUtc.isAfter(voteDeadlineUtc);

          // --- OYLAMA KOŞULLARINI KONTROL ET ---
          final bool canVote = _checkVotingEligibility(
            match,
            currentUserId,
            acceptedParticipants,
            nowUtc,
            matchEndTimeUtc,
            voteDeadlineUtc,
          ); // nowUtc parametrelerini ekledik
          // --- KONTROL BİTTİ ---
          final bool attendanceSubmitted = acceptedParticipants.any(
            (p) => p.attended != null,
          );

          // Tarih formatlama
          final formattedDate = DateFormat(
            'dd MMMM yyyy, HH:mm',
          ).format(match.startTime.toLocal()); // startTime artık DateTime

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (field != null)
                  _FieldInfoCard(
                    field: field,
                    onDirectionsPressed: () => _launchMaps(context, field),
                  ),

                const SizedBox(height: 16), // Kartlar arası boşluk
                // --- 2. KART: MAÇ BİLGİLERİ ---
                _MatchInfoCard(match: match, formattedDate: formattedDate),
                const Divider(height: 32),

                // --- Organizatör ---
                Text(
                  'Organizatör',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (organizer != null) // Null kontrolü
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          organizer.displayImageUrl.startsWith('http')
                          ? NetworkImage(organizer.displayImageUrl)
                          : const AssetImage(
                              'assets/images/default_profile.jpg',
                            ), // User modelindeki getter'ı kullan
                    ),
                    title: Text(organizer.fullName),
                    onTap: () => context.go('/profile/${organizer.id}'),
                  ),
                const Divider(height: 32),

                // --- Katılımcılar ---
                Text(
                  'Katılımcılar (${match.acceptedParticipantCount} / ${match.maxCapacity})', // Modeldeki getter'ları kullan
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                // TODO: Katılımcıları daha güzel bir Grid veya Liste ile göster
                if (acceptedParticipants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Henüz kabul edilmiş katılımcı yok.'),
                  )
                else
                  // GridView.builder ile gösterelim (2 sütunlu)
                  GridView.builder(
                    shrinkWrap: true, // ScrollView içinde
                    physics:
                        const NeverScrollableScrollPhysics(), // ScrollView içinde
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // Yan yana 2 kart
                          childAspectRatio:
                              3.5 /
                              1.5, // Kartların en/boy oranı (deneyerek ayarla)
                          crossAxisSpacing: 8, // Kartlar arası yatay boşluk
                          mainAxisSpacing: 8, // Kartlar arası dikey boşluk
                        ),
                    itemCount: acceptedParticipants.length,
                    itemBuilder: (context, index) {
                      final participant = acceptedParticipants[index];
                      // ParticipantCard widget'ını kullan
                      return ParticipantCard(participant: participant);
                    },
                  ),
                // --- Katılımcılar Bölümü BİTTİ ---

                // --- KAPTAN İSE ONAY BEKLEYENLERİ GÖSTER (GÜNCELLENMİŞ) ---
                if (userIsCaptain && requestedParticipants.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Onay Bekleyenler (${requestedParticipants.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requestedParticipants.length,
                    itemBuilder: (context, index) {
                      final participant = requestedParticipants[index];
                      final user = participant.user;
                      if (user == null) return const SizedBox.shrink();

                      final bool isProcessingThis =
                          processingParticipantId.value == participant.id;
                      final bool isAnyProcessing =
                          matchesNotifierState.isUpdatingParticipant ||
                          isProcessingThis;
                      final bool rosterFull =
                          match.acceptedParticipantCount >= match.maxCapacity;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                user.displayImageUrl.startsWith('http')
                                ? NetworkImage(user.displayImageUrl)
                                : const AssetImage(
                                    'assets/images/default_profile.jpg',
                                  ),
                          ),
                          title: Text(user.fullName),
                          subtitle: Text(
                            'Pozisyon İsteği: ${participant.positionRequest ?? "Belirtilmemiş"}',
                          ),
                          trailing: isProcessingThis
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Reddet Butonu
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Reddet',
                                      onPressed: isAnyProcessing
                                          ? null
                                          : () async {
                                              processingParticipantId.value =
                                                  participant.id;
                                              try {
                                                await ref
                                                    .read(
                                                      matchesNotifierProvider
                                                          .notifier,
                                                    )
                                                    .updateParticipantStatus(
                                                      matchId: matchId,
                                                      participantId:
                                                          participant.id,
                                                      status: 'declined',
                                                    );
                                                if (context.mounted) {
                                                  // Detayı yenile
                                                  ref.invalidate(
                                                    matchDetailProvider(
                                                      matchId,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Başvuru reddedildi',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        e
                                                            .toString()
                                                            .replaceFirst(
                                                              'Exception: ',
                                                              '',
                                                            ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                    ),
                                                  );
                                                }
                                              } finally {
                                                if (context.mounted) {
                                                  processingParticipantId
                                                          .value =
                                                      null;
                                                }
                                              }
                                            },
                                    ),
                                    // Onayla Butonu
                                    IconButton(
                                      icon: Icon(
                                        Icons.check,
                                        color:
                                            (matchesNotifierState
                                                    .isUpdatingParticipant ||
                                                processingParticipantId.value ==
                                                    participant.id)
                                            ? Colors.grey
                                            : (rosterFull
                                                  ? Colors.orange
                                                  : Colors.green),
                                      ),
                                      tooltip: rosterFull
                                          ? 'Kadroyu aştı'
                                          : 'Onayla',
                                      onPressed: isAnyProcessing
                                          ? null
                                          : () async {
                                              if (rosterFull) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Maç kadrosu dolu. Onay verilemez.',
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                }
                                                return;
                                              }
                                              processingParticipantId.value =
                                                  participant.id;
                                              try {
                                                await ref
                                                    .read(
                                                      matchesNotifierProvider
                                                          .notifier,
                                                    )
                                                    .updateParticipantStatus(
                                                      matchId: matchId,
                                                      participantId:
                                                          participant.id,
                                                      status: 'accepted',
                                                    );
                                                if (context.mounted) {
                                                  ref.invalidate(
                                                    matchDetailProvider(
                                                      matchId,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Oyuncu onaylandı',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        e
                                                            .toString()
                                                            .replaceFirst(
                                                              'Exception: ',
                                                              '',
                                                            ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                    ),
                                                  );
                                                }
                                              } finally {
                                                if (context.mounted) {
                                                  processingParticipantId
                                                          .value =
                                                      null;
                                                }
                                              }
                                            },
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ], // --- ONAY BEKLEYENLER BÖLÜMÜ BİTTİ ---
                // --- YENİ BÖLÜM: KAPTAN KATILIM ONAYI ---
                // Eğer kullanıcı kaptansa, maç bitmişse VE katılım henüz onaylanmamışsa
                if (userIsCaptain && matchIsOver && !attendanceSubmitted) ...[
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Katılımı Onayla',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Maç sona erdi. Lütfen maça GELMEYEN oyuncuları işaretleyin. İşaretlenmeyen herkes "geldi" sayılacaktır.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Kaptan dışındaki 'accepted' katılımcıları listele
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8.0, // Çipler arası yatay boşluk
                      runSpacing: 8.0, // Çipler arası dikey boşluk
                      children: acceptedParticipants.map((participant) {
                        final user = participant.user;
                        // Kaptanın kendisini listede gösterme
                        if (user == null || user.id == currentUserId)
                          return const SizedBox.shrink();

                        // Lokal state'ten "gelmedi" olarak işaretlenip işaretlenmediğini kontrol et
                        final bool isMarkedAsNoShow = noShowUserIds.value
                            .contains(user.id);
                        // "Geldi" durumu, "gelmedi" listesinde olmamasıdır
                        final bool attended = !isMarkedAsNoShow;

                        return FilterChip(
                          label: Text(user.fullName),
                          avatar: CircleAvatar(
                            backgroundImage:
                                user.displayImageUrl.startsWith('http')
                                ? NetworkImage(user.displayImageUrl)
                                : AssetImage(user.displayImageUrl)
                                      as ImageProvider,
                          ),
                          // "Geldi" ise seçili (yeşil), "Gelmedi" ise seçili değil (gri)
                          selected: attended,
                          selectedColor: Colors.green.withOpacity(0.3),
                          checkmarkColor: Colors.green.shade700,
                          showCheckmark: true,
                          // Yüklenme sırasında pasif yap
                          onSelected:
                              matchesNotifierState.isSubmittingAttendance
                              ? null
                              : (bool isNowSelected) {
                                  // isNowSelected = true -> "Geldi" olarak işaretlendi
                                  // isNowSelected = false -> "Gelmedi" olarak işaretlendi
                                  final currentSet = noShowUserIds.value
                                      .toSet(); // Kopyasını al
                                  if (isNowSelected) {
                                    // "Geldi"ye tıklandı -> "Gelmeyenler" listesinden çıkar
                                    currentSet.remove(user.id);
                                  } else {
                                    // "Gelmedi"ye tıklandı -> "Gelmeyenler" listesine ekle
                                    currentSet.add(user.id);
                                  }
                                  noShowUserIds.value =
                                      currentSet; // State'i güncelle
                                },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    // Yükleniyorsa indicator göster
                    child: matchesNotifierState.isSubmittingAttendance
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () async {
                              // Notifier'ı çağır
                              final success = await ref
                                  .read(matchesNotifierProvider.notifier)
                                  .submitAttendance(
                                    matchId: matchId,
                                    noShowUserIds: noShowUserIds.value
                                        .toList(), // Set'i List'e çevir
                                  );
                              if (success && context.mounted) {
                                // Başarılı olunca bu bölüm kaybolacak (çünkü invalidate olacak)
                                // SnackBar zaten 'ref.listen' tarafından gösterilecek.
                                noShowUserIds.value =
                                    {}; // Lokal state'i temizle
                              }
                            },
                            child: const Text('Katılım Listesini Onayla'),
                          ),
                  ),
                ],
                // --- KAPTAN KATILIM ONAYI BÖLÜMÜ BİTTİ ---
                const Divider(height: 32),

                // --- OYLAMA BÖLÜMÜ ---
                // --- GÜNCELLENMİŞ OYLAMA BÖLÜMÜ ---
                if (votingWindowOpen && canVote)
                  Padding(
                    key: votingSectionKey,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    // _buildVotingSection yerine yeni widget'ı çağır
                    child: MatchVotingWidget(
                      matchId: match.id,
                      // Kendimiz dışındaki katılımcıları gönder
                      otherPlayers: acceptedParticipants
                          .where(
                            (p) => p.userId != currentUserId && p.user != null,
                          )
                          .toList(),
                    ),
                  )
                else if (votingWindowClosed)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        "Oylama penceresi kapandı.",
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                // --- OYLAMA BÖLÜMÜ BİTTİ ---

                // --- Aksiyon Butonları ---
                // Önce mevcut kullanıcı ID'sini alalım
                if (currentUserId == null)
                  const Center(
                    child: Text("Butonları görmek için giriş yapın."),
                  )
                else
                  Builder(
                    builder: (context) {
                      final MatchParticipant? currentUserParticipation = match
                          .participants
                          ?.firstWhereOrNull((p) => p.userId == currentUserId);
                      final bool isFull =
                          match.acceptedParticipantCount >= match.maxCapacity;

                      Widget actionButton;

                      // 1. Maç Başladı veya Bitti mi? (Artık Join/Leave mümkün değil)
                      if (matchHasStarted) {
                        // Maç başladıysa veya bittiyse
                        // Kullanıcının durumuna göre bilgi mesajı gösterelim
                        if (currentUserParticipation?.status == 'accepted') {
                          actionButton = const ElevatedButton(
                            onPressed: null,
                            child: Text('Maç Başladı/Bitti'),
                          );
                        } else if (currentUserParticipation?.status ==
                            'requested') {
                          actionButton = const ElevatedButton(
                            onPressed: null,
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                Colors.orangeAccent,
                              ),
                            ),
                            child: Text('Onay Bekleniyor'),
                          );
                        } else {
                          actionButton = const ElevatedButton(
                            onPressed: null,
                            child: Text('Maç Başladı/Bitti'),
                          );
                        }
                      }
                      // Durum 2: Kullanıcı 'accepted'
                      else if (currentUserParticipation?.status == 'accepted') {
                        // Kaptan mı kontrolü (kaptan ayrılamaz)
                        final isCaptain = match.organizerId == currentUserId;
                        actionButton = ElevatedButton(
                          onPressed:
                              isCaptain ||
                                  matchesNotifierState.isJoiningOrLeaving
                              ? null // Kaptansa veya işlem sürüyorsa pasif
                              : () async {
                                  // Leave Match
                                  final success = await ref
                                      .read(matchesNotifierProvider.notifier)
                                      .leaveMatch(matchId: matchId);
                                  if (!success && context.mounted) {
                                    // Hata SnackBar'ı zaten Notifier/Listen tarafından gösterilecek
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCaptain
                                ? Colors.grey
                                : Colors.redAccent,
                          ),
                          child: Text(
                            isCaptain ? 'Kaptan Ayrılamaz' : 'Maçtan Ayrıl',
                          ),
                        );
                      }
                      // Durum 3: Kullanıcı 'requested'
                      else if (currentUserParticipation?.status ==
                          'requested') {
                        actionButton = ElevatedButton(
                          onPressed: null, // Pasif
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                          ),
                          child: const Text('İstek Gönderildi'),
                        );
                      }
                      // Durum 4: Kullanıcı katılmamış ve yer var
                      else {
                        actionButton = ElevatedButton(
                          onPressed: matchesNotifierState.isJoiningOrLeaving
                              ? null // İşlem sürüyorsa pasif
                              : () async {
                                  // Join Match
                                  String? requestedPosition;
                                  // Eğer maç onay gerektiriyorsa pozisyon sor
                                  if (match.joinType == 'approval_required') {
                                    // Dialog'u göster ve sonucu bekle
                                    final result = await showDialog<String?>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return const _PositionSelectionDialog();
                                      },
                                    );

                                    // Eğer kullanıcı "İptal"e basmadıysa (null değilse)
                                    // ve bir pozisyon seçtiyse (yine null değilse)
                                    // NOT: Dialog'dan dönen değer zaten 'null' olabilir (Belirtmek İstemiyorum)
                                    // Bu yüzden sadece dialog'un kapatılmadığını kontrol edelim
                                    // Aslında dialog iptal edilse bile null göndermek istiyoruz.
                                    // Belki dialog'dan özel bir değer döndürmeliydik iptal için?
                                    // Şimdilik: Eğer dialog null döndürürse (iptal veya belirtmek istemiyorum), null gönderelim.
                                    requestedPosition = result;

                                    // İsteğe bağlı: Eğer kullanıcı iptal ettiyse API çağrısını yapmayabiliriz.
                                    // Ancak backend zaten positionRequest'i null kabul ediyor.
                                    // print("Seçilen Pozisyon: $requestedPosition");
                                  }

                                  final success = await ref
                                      .read(matchesNotifierProvider.notifier)
                                      .joinMatch(
                                        matchId: matchId,
                                        positionRequest: requestedPosition,
                                      );

                                  if (!success && context.mounted) {
                                    // Hata SnackBar'ı ref.listen tarafından gösterilecek
                                    debugPrint("Join match failed.");
                                  }
                                  // Başarı SnackBar'ı ve UI güncellemesi (invalidate) Notifier içinde
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text(
                            match.joinType == 'open'
                                ? 'Maça Katıl'
                                : 'Katılma İsteği Gönder',
                          ),
                        );
                      }

                      // Yüklenme durumunu buton üzerinde gösterelim
                      return Center(
                        child: matchesNotifierState.isJoiningOrLeaving
                            ? const CircularProgressIndicator()
                            : actionButton,
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- OYLAMA UYGUNLUĞUNU KONTROL EDEN YARDIMCI FONKSİYON ---
  bool _checkVotingEligibility(
    Match match,
    String? currentUserId,
    List<MatchParticipant> acceptedParticipants,
    DateTime nowUtc, // Parametre olarak alalım
    DateTime matchEndTimeUtc, // Parametre olarak alalım
    DateTime voteDeadlineUtc, // Parametre olarak alalım
  ) {
    if (currentUserId == null) {
      debugPrint("[Vote Eligibility] FAILED: No current user ID.");
      return false; // Giriş yapmamış
    }
    // 1. Zaman Kontrolü (TÜMÜNÜ UTC'DE KARŞILAŞTIR)
    // match.startTime zaten UTC
    final matchEndTimeUtc = match.startTime.add(
      Duration(minutes: match.durationMinutes),
    );
    final voteDeadlineUtc = matchEndTimeUtc.add(
      const Duration(minutes: 60),
    ); // 60 dakika pencere
    // Şimdiki zamanı da UTC olarak al
    final nowUtc = DateTime.now().toUtc();

    debugPrint(">>> Voting Time Check (UTC):");
    debugPrint(">>>   Match Start UTC: ${match.startTime}");
    debugPrint(">>>   Match End UTC:   $matchEndTimeUtc");
    debugPrint(">>>   Vote Deadline UTC: $voteDeadlineUtc");
    debugPrint(">>>   Current Time UTC:  $nowUtc");

    // Maç bitmemişse VEYA oylama süresi geçmişse oy kullanamaz
    if (nowUtc.isBefore(matchEndTimeUtc) || nowUtc.isAfter(voteDeadlineUtc)) {
      debugPrint(
        "[Vote Eligibility] FAILED: Current time is outside the voting window.",
      );
      return false;
    }
    debugPrint("[Vote Eligibility] PASSED: Time check.");

    // 2. Katılım Kontrolü
    final currentUserParticipation = acceptedParticipants.firstWhereOrNull(
      (p) => p.userId == currentUserId,
    );

    debugPrint("[Vote Eligibility] Checking participation:");
    debugPrint(
      ">>>   Participation Record Found: ${currentUserParticipation != null}",
    );
    debugPrint(">>>   Attended Status: ${currentUserParticipation?.attended}");

    if (currentUserParticipation == null ||
        currentUserParticipation.attended != true) {
      debugPrint(
        "[Vote Eligibility] FAILED: User did not attend or participation record not found.",
      );
      return false;
    }
    debugPrint("[Vote Eligibility] PASSED: Participation check.");

    // TODO: Zaten oy kullanıldı mı kontrolü

    debugPrint("[Vote Eligibility] PASSED Overall.");
    return true; // Tüm koşullar sağlandı
  }

  // Oylama penceresinin kapanıp kapanmadığını kontrol eden yardımcı fonksiyon
  bool _isVotingWindowClosed(Match match) {
    final matchEndTimeUtc = match.startTime.add(
      Duration(minutes: match.durationMinutes),
    );
    final voteDeadlineUtc = matchEndTimeUtc.add(const Duration(minutes: 60));
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.isAfter(voteDeadlineUtc);
  }

  // --- OYLAMA UI'INI OLUŞTURAN YARDIMCI FONKSİYON ---
  Widget _buildVotingSection(
    BuildContext context,
    WidgetRef ref,
    Match match,
    String currentUserId,
    List<MatchParticipant> participants,
    VotesState votesState, // Oylama işleminin durumunu al
  ) {
    // Kendimiz dışındaki katılımcıları al
    final otherPlayers = participants
        .where((p) => p.userId != currentUserId && p.user != null)
        .toList();
    if (otherPlayers.isEmpty)
      return const SizedBox.shrink(); // Başka oyuncu yoksa oylama yapamaz

    // Hook'ları build metodunun dışında kullanamayız, bu yüzden state'leri
    // bu fonksiyonun dışında (build içinde) tanımlayıp buraya parametre olarak geçebiliriz
    // VEYA bu bölümü ayrı bir HookConsumerWidget yapabiliriz. Şimdilik basit tutalım.
    // MVP ve Etiket için seçilen kullanıcıları tutacak state'e ihtiyacımız olacak.
    // Bunu geçici olarak build içinde useState ile yapabiliriz (ideal değil ama hızlı)
    // VEYA VotesNotifier'a ekleyebiliriz.

    // VotesNotifier'ı çağıran fonksiyonlar
    void _submitMvp(String votedUserId) {
      ref
          .read(votesNotifierProvider.notifier)
          .submitMvpVote(matchId: match.id, votedUserId: votedUserId);
    }

    void _submitTag(String taggedUserId, String tagId) {
      ref
          .read(votesNotifierProvider.notifier)
          .submitTagVote(
            matchId: match.id,
            taggedUserId: taggedUserId,
            tagId: tagId,
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Maç Sonu Oylama', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        // TODO: Kullanıcının oy kullanıp kullanmadığını kontrol edip UI'ı ona göre ayarla
        // if (!votesState.mvpVoteSubmitted) ...

        // --- MVP Seçimi ---
        Text(
          'Maçın Oyuncusu (MVP):',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        // Oyuncuları listeleyip seçtirme (örn: RadioListTile)
        Wrap(
          // Veya ListView
          spacing: 8.0,
          children: otherPlayers.map((p) {
            final user = p.user!;
            return ActionChip(
              avatar: CircleAvatar(
                backgroundImage: user.displayImageUrl.startsWith('http')
                    ? NetworkImage(user.displayImageUrl)
                    : const AssetImage('assets/images/default_profile.jpg'),
              ),
              label: Text(user.fullName),
              // TODO: Seçili oyuncuyu belirtmek için state kullan
              // backgroundColor: selectedMvpUserId == user.id ? Colors.green : null,
              onPressed: votesState.isSubmitting
                  ? null
                  : () {
                      // TODO: Seçili MVP ID'sini state'e ata
                      // _submitMvp(user.id); // VEYA ayrı bir "Gönder" butonu ile
                      print("MVP seçildi: ${user.id} (Gönderilmedi)"); // Geçici
                      _submitMvp(user.id); // Şimdilik direkt gönderelim
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // --- Etiket Seçimi ---
        Text(
          'Öne Çıkan Performans (1 Etiket):',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8), // Başlık ile liste arasına boşluk
        // Oyuncuları Column içinde listele
        Column(
          children: otherPlayers.map((p) {
            final user = p.user!;
            return Card(
              // Her oyuncu için bir Kart oluşturalım
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  // Row yerine Column
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Oyuncu Bilgisi (Avatar + İsim)
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              user.displayImageUrl.startsWith('http')
                              ? NetworkImage(user.displayImageUrl)
                              : const AssetImage(
                                  'assets/images/default_profile.jpg',
                                ),
                          radius: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    ), // İsim ile etiketler arasına boşluk
                    // Etiket Butonları (Wrap içinde)
                    Wrap(
                      spacing: 6.0, // Butonlar arası boşluk
                      runSpacing: 4.0, // Satırlar arası boşluk
                      children: availableTags.entries.map((entry) {
                        final tagId = entry.key;
                        final tagName = entry.value;
                        return ActionChip(
                          label: Text(
                            tagName,
                            style: const TextStyle(fontSize: 11),
                          ), // Biraz küçültebiliriz
                          tooltip: 'Etiketi ${user.fullName} için gönder',
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ), // Daha sıkı padding
                          labelPadding: EdgeInsets.zero,
                          visualDensity:
                              VisualDensity.compact, // Daha kompakt görünüm
                          onPressed: votesState.isSubmitting
                              ? null
                              : () {
                                  _submitTag(user.id, tagId);
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// --- YENİ WIDGET: Pozisyon Seçme Dialog'u ---
class _PositionSelectionDialog extends StatefulWidget {
  const _PositionSelectionDialog({Key? key}) : super(key: key);

  @override
  State<_PositionSelectionDialog> createState() =>
      _PositionSelectionDialogState();
}

class _PositionSelectionDialogState extends State<_PositionSelectionDialog> {
  // Seçenekler
  final List<String> positions = [
    'Forvet',
    'Orta Saha',
    'Defans',
    'Kaleci',
    'Belirtmek İstemiyorum',
  ];
  String? _selectedPosition; // Seçilen pozisyonu tutacak state

  @override
  void initState() {
    super.initState();
    _selectedPosition =
        positions.last; // Varsayılan olarak son seçeneği seçili yap
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pozisyon Seçin'),
      content: Column(
        mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlan
        children: positions.map((position) {
          return RadioListTile<String>(
            title: Text(position),
            value: position,
            groupValue: _selectedPosition,
            onChanged: (String? value) {
              setState(() {
                _selectedPosition = value;
              });
            },
          );
        }).toList(),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('İptal'),
          onPressed: () {
            Navigator.of(context).pop(); // Dialog'u kapat, null döndür
          },
        ),
        TextButton(
          child: const Text('Gönder'),
          onPressed: () {
            // Seçilen pozisyonu (veya "Belirtmek İstemiyorum" ise null) geri döndür
            final result = _selectedPosition == 'Belirtmek İstemiyorum'
                ? null
                : _selectedPosition;
            Navigator.of(context).pop(result);
          },
        ),
      ],
    );
  }
}
// --- DIALOG WIDGET BİTTİ ---

// Helper Provider: Giriş yapmış kullanıcının ID'sini almak için
// Bu provider AuthRepository'yi kullanır ve token'ı decode eder (veya backend'den /me endpoint'i çağırır)
// Basitlik adına şimdilik token'dan decode edelim (jwt_decoder paketi gerekir: flutter pub add jwt_decoder)
// import 'package:jwt_decoder/jwt_decoder.dart';
// import 'package:paslas_app/features/auth/repositories/auth_repository.dart';

final currentUserProvider = FutureProvider<String?>((ref) async {
  final authRepository = ref.watch(authRepositoryProvider);
  final token = await authRepository.getToken();
  if (token == null) return null;
  try {
    // Eğer jwt_decoder eklersek:
    // Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
    // return decodedToken['sub']; // 'sub' claim'i genellikle user ID'dir

    // Şimdilik backend'den /profile/me çağırmak daha güvenli olabilir
    // (ProfileRepository ve Provider oluşturmamız gerekir)
    // VEYA AuthNotifier state'ine userId ekleyebiliriz.
    // EN BASİT GEÇİCİ ÇÖZÜM: AuthNotifier'dan durumu alıp user objesini döndürmek
    // (Bu ideal değil ama hızlı bir başlangıç)

    // AuthRepository'ye /profile/me isteği atacak bir metot ekleyelim
    // VEYA AuthNotifier'a user bilgisini ekleyelim.
    // ŞİMDİLİK GEÇİCİ OLARAK NULL DÖNDÜRELİM
    print("TODO: Implement currentUserId fetching!");
    return null; // Gerçek implementasyon gerekiyor!
  } catch (e) {
    print("Token decode/fetch error: $e");
    return null;
  }
});

// --- YENİ YARDIMCI WIDGET: _FieldInfoCard ---
class _FieldInfoCard extends StatelessWidget {
  final Field field;
  final VoidCallback onDirectionsPressed;

  const _FieldInfoCard({
    required this.field,
    required this.onDirectionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias, // Haritanın kenarlarını kartla kırması için
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Harita
          if (field.location != null)
            SizedBox(
              height: 180, // Harita yüksekliği
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    field.location!.latitude,
                    field.location!.longitude,
                  ),
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag
                        .none, // Haritayı tıklanmaz/kaydırılmaz yap (sadece gösterim)
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                    userAgentPackageName:
                        'com.example.flutter_baab_sport_field_app', // Kendi paket adınız
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: LatLng(
                          field.location!.latitude,
                          field.location!.longitude,
                        ),
                        child: Icon(
                          Icons.location_pin,
                          color: Colors.red.shade700,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Bilgi ve Buton
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.address ?? 'Adres bilgisi yok',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Yol Tarifi Butonu
                ElevatedButton.icon(
                  onPressed: () {
                    debugPrint('onDirectionsPressed: $onDirectionsPressed');
                    onDirectionsPressed();
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Yol Tarifi'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: Colors.green.shade700, // Buton rengi
                    foregroundColor: Colors.white, // Yazı rengi
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// --- YARDIMCI WIDGET BİTTİ ---

// --- YENİ YARDIMCI WIDGET: _MatchInfoCard ---
class _MatchInfoCard extends StatelessWidget {
  final Match match;
  final String formattedDate;

  const _MatchInfoCard({required this.match, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              title: 'Tarih',
              value: formattedDate,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.schedule_outlined,
                    title: 'Süre',
                    value: '${match.durationMinutes} dakika',
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey.shade700,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ), // Dikey ayraç
                Expanded(
                  child: _InfoRow(
                    icon: Icons.people_outline,
                    title: 'Format',
                    value: match.format,
                  ),
                ),
              ],
            ),
            if (match.notes != null && match.notes!.isNotEmpty) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.notes_outlined,
                title: 'Notlar',
                value: match.notes!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
// --- YARDIMCI WIDGET BİTTİ ---

// --- YENİ YARDIMCI WIDGET: _InfoRow ---
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
