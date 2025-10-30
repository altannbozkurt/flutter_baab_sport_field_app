// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/core/providers/location_provider.dart'; // Konum Notifier'ı
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart'; // Auth Notifier'ı (Logout için)
import 'package:flutter_baab_sport_field_app/features/matches/providers/matches_notifier_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // Maç Notifier'ı

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth state'ini (logout butonu için) ve Maç state'ini dinle
    final authState = ref.watch(authNotifierProvider);
    final matchesState = ref.watch(matchesNotifierProvider);
    // Konum state'ini de dinle (izin/hata durumlarını göstermek için)
    final locationState = ref.watch(locationNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maçlar'),
        actions: [
          // Yenileme Butonu (opsiyonel, pull-to-refresh de eklenebilir)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: authState.isLoading || matchesState.isLoading
                ? null // Yüklenirken pasif
                : () => ref
                      .read(matchesNotifierProvider.notifier)
                      .refreshMatches(),
          ),

          // Logout Butonu
        ],
      ),
      body: _buildBody(
        context,
        ref,
        locationState,
        matchesState,
      ), // Body'yi ayrı bir fonksiyona taşıdık
    );
  }

  // Body içeriğini state'lere göre oluşturan yardımcı fonksiyon
  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    LocationState locationState,
    MatchesState matchesState,
  ) {
    // 1. Konum İzin/Hata Kontrolü
    if (locationState.error != null && locationState.position == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                locationState.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref
                    .read(locationNotifierProvider.notifier)
                    .requestPermissionAgain(),
                child: Text(
                  locationState.permission == LocationPermission.deniedForever
                      ? 'Ayarları Aç'
                      : 'Tekrar Dene',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Yüklenme Durumu (Konum veya Maçlar yükleniyor)
    if (matchesState.isLoading || locationState.position == null) {
      // Konum bekleniyor olabilir veya maçlar yükleniyor olabilir
      return const Center(child: CircularProgressIndicator());
    }

    // 3. Maçlar Yüklendi Ama Hata Var (API Hatası)
    if (matchesState.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Maçlar yüklenirken bir hata oluştu:\n${matchesState.errorMessage}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    ref.read(matchesNotifierProvider.notifier).refreshMatches(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Maç Listesi Boş
    if (matchesState.matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Yakınınızda herkese açık maç bulunamadı.'),
            const SizedBox(height: 20),
            ElevatedButton(
              // Yeni maç oluşturma butonu (ileride eklenecek)
              onPressed: () {
                context.go('/create-match');
                /* TODO: Maç oluşturma ekranına git */
              },
              child: const Text('İlk Maçı Sen Oluştur!'),
            ),
          ],
        ),
      );
    }

    // 5. Maç Listesi Dolu -> Bölümlendirilmiş liste (Yaklaşan / Yeni Biten)
    final now = DateTime.now().toUtc();
    final upcoming = <Map<String, dynamic>>[];
    final recentFinished = <Map<String, dynamic>>[];

    for (final match in matchesState.matches) {
      final String? startTimeStr = match['match_start_time'] as String?;
      DateTime? startUtc;
      if (startTimeStr != null) {
        try {
          startUtc = DateTime.parse(startTimeStr).toUtc();
        } catch (e) {
          debugPrint('start_time parse hatası: $e');
        }
      }
      // startUtc yoksa yaklaşan kabul et (görünsün)
      if (startUtc == null || startUtc.isAfter(now)) {
        upcoming.add(match);
      } else {
        // Basit yaklaşım: start geçmişse "biten" kabul et (geliştirilebilir)
        recentFinished.add(match);
      }
    }

    // Sıralamalar
    upcoming.sort((a, b) {
      final as = DateTime.tryParse(
        (a['match_start_time']?.toString() ?? ''),
      )?.toUtc();
      final bs = DateTime.tryParse(
        (b['match_start_time']?.toString() ?? ''),
      )?.toUtc();
      if (as == null && bs == null) return 0;
      if (as == null) return 1;
      if (bs == null) return -1;
      return as.compareTo(bs);
    });
    recentFinished.sort((a, b) {
      final as = DateTime.tryParse(
        (a['match_start_time']?.toString() ?? ''),
      )?.toUtc();
      final bs = DateTime.tryParse(
        (b['match_start_time']?.toString() ?? ''),
      )?.toUtc();
      if (as == null && bs == null) return 0;
      if (as == null) return 1;
      if (bs == null) return -1;
      return bs.compareTo(as);
    });

    Widget buildMatchCard(Map<String, dynamic> match) {
      final String? matchId = match['match_id'] as String?;
      final String? startTimeStr = match['match_start_time'] as String?;
      final String? formatStr = match['match_format'] as String?;
      final int currentPlayers =
          int.tryParse(match['participantCount']?.toString() ?? '0') ?? 0;

      // Tarih
      String formattedDate = 'Tarih Bilinmiyor';
      if (startTimeStr != null) {
        try {
          final startTimeLocal = DateTime.parse(startTimeStr).toLocal();
          formattedDate = DateFormat('dd MMM, HH:mm').format(startTimeLocal);
        } catch (e) {
          debugPrint('Tarih parse hatası: $e');
        }
      }

      // Kapasite
      String displayFormat = formatStr ?? '?';
      int totalPlayers = 0;
      if (formatStr != null) {
        try {
          final parts = formatStr.toLowerCase().split('v');
          if (parts.length == 2) {
            final perSide = int.tryParse(parts[0]);
            if (perSide != null) totalPlayers = perSide * 2;
          }
        } catch (e) {
          debugPrint('Format parse hatası: $e');
        }
      }

      final startUtc = startTimeStr != null
          ? DateTime.tryParse(startTimeStr)?.toUtc()
          : null;
      final isUpcoming = startUtc == null || startUtc.isAfter(now);
      final statusLabel = isUpcoming ? 'Yaklaşan' : 'Bitti';

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ListTile(
          onTap: () => context.go('/matches/$matchId'),
          title: Row(
            children: [
              Expanded(child: Text(match['field_name'] ?? 'Bilinmeyen Saha')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isUpcoming
                      ? Colors.blue.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: isUpcoming ? Colors.blue : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text('📅 $formattedDate\n👥 Format: $displayFormat'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currentPlayers / ${totalPlayers > 0 ? totalPlayers : '?'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: (totalPlayers > 0 && currentPlayers >= totalPlayers)
                      ? Colors.redAccent
                      : null,
                ),
              ),
              if (!isUpcoming)
                InkWell(
                  onTap: () => context.go('/matches/$matchId'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Hemen Oy Ver',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          isThreeLine: true,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(matchesNotifierProvider.notifier).refreshMatches(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (upcoming.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'Yaklaşan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcoming.length,
                  itemBuilder: (_, i) =>
                      _MatchCard(match: upcoming[i], isUpcoming: true),
                ),
              ],
              if (recentFinished.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    'Yeni Biten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentFinished.length,
                  itemBuilder: (_, i) =>
                      _MatchCard(match: recentFinished[i], isUpcoming: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// YENİ: Modern Maç Kartı Widget'ı
///
// lib/features/home/screens/home_screen.dart -> Dosyanın en altındaki _MatchCard class'ını bununla değiştirin

///
/// YENİ: Modern Maç Kartı Widget'ı (Tıklama Hatası Düzeltildi)
///
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool isUpcoming;

  const _MatchCard({required this.match, required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    // --- Verileri ayrıştıralım
    final String? matchId = match['match_id'] as String?;
    final String? fieldName = match['field_name'] ?? 'Bilinmeyen Saha';
    final String? startTimeStr = match['match_start_time'] as String?;
    final String? formatStr = match['match_format'] as String?;
    final int currentPlayers =
        int.tryParse(match['participantCount']?.toString() ?? '0') ?? 0;

    // --- Tarih formatlama
    String formattedDate = 'Tarih Bilinmiyor';
    String formattedTime = 'Saati Yok';
    if (startTimeStr != null) {
      try {
        final startTimeLocal = DateTime.parse(startTimeStr).toLocal();
        formattedDate = DateFormat('MMMM dd', 'en_US').format(startTimeLocal);
        formattedTime = DateFormat('h:mm a', 'en_US').format(startTimeLocal);
      } catch (e) {
        debugPrint('Tarih parse hatası (en_US): $e');
      }
    }

    // --- Kapasite formatlama
    String displayFormat = formatStr ?? '?v?';
    int totalPlayers = 0;
    if (formatStr != null) {
      try {
        final parts = formatStr.toLowerCase().split('v');
        if (parts.length == 2 && parts[0].isNotEmpty) {
          final perSide = int.tryParse(parts[0]);
          if (perSide != null) totalPlayers = perSide * 2;
        }
      } catch (e) {
        //...
      }
    }
    final bool isFull = (totalPlayers > 0 && currentPlayers >= totalPlayers);

    // --- Kart Arayüzü ---
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        // Ana InkWell kaldırıldı, yerine Column geldi
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. & 2. BÖLÜMLER: Info Sekmesine Giden Tıklama Alanı ---
          GestureDetector(
            behavior: HitTestBehavior
                .opaque, // Boş alanların da tıklamayı almasını sağlar
            onTap: () {
              if (matchId != null) {
                context.go('/matches/$matchId'); // Info sekmesine git
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Başlık (Saha Adı) ve Durum Etiketi ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          fieldName ?? 'Bilinmeyen Saha',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusChip(isUpcoming: isUpcoming),
                    ],
                  ),
                ),

                // --- 2. Bilgi Satırı (Tarih, Saat, Format) ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    children: [
                      _InfoIconText(
                        icon: Icons.calendar_today_outlined,
                        text: formattedDate,
                      ),
                      const SizedBox(width: 16),
                      _InfoIconText(
                        icon: Icons.access_time_outlined,
                        text: formattedTime,
                      ),
                      const SizedBox(width: 16),
                      _InfoIconText(
                        icon: Icons.people_alt_outlined,
                        text: displayFormat,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- 3. BÖLÜM: Katılımcı Sayısı & Oy Ver Butonu (Ayrı Tıklama Alanı) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.person_pin_circle_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$currentPlayers / ${totalPlayers > 0 ? totalPlayers : '?'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isFull ? Colors.redAccent : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // --- 'Rate & Review' Tıklama Alanı (Değişmedi ama artık çakışmayacak) ---
                if (!isUpcoming) ...[
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: InkWell(
                        onTap: () {
                          if (matchId != null) {
                            context.go('/matches/$matchId?tab=voting');
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Rate & Review',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --- 4. BÖLÜM: Doluluk Oranı Çubuğu ---
          if (isUpcoming && totalPlayers > 0)
            GestureDetector(
              // Bu da Info'ya gitsin
              onTap: () {
                if (matchId != null) {
                  context.go('/matches/$matchId'); // Info sekmesine git
                }
              },
              child: LinearProgressIndicator(
                value: currentPlayers / totalPlayers,
                backgroundColor: Colors.grey.withOpacity(0.2),
                color: isFull
                    ? Colors.redAccent
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// YENİ: Durum (Yaklaşan/Bitti) etiketini oluşturan widget
class _StatusChip extends StatelessWidget {
  final bool isUpcoming;
  const _StatusChip({required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    final color = isUpcoming ? Colors.blue : Colors.green;
    final label = isUpcoming ? 'Yaklaşan' : 'Bitti';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// YENİ: İkon + Metin (Tarih, Saat, Format) oluşturan widget
class _InfoIconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoIconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade200, // Temanıza göre ayarlayabilirsiniz
          ),
        ),
      ],
    );
  }
}
