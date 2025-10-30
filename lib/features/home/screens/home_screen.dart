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
        title: const Text('Yakındaki Maçlar'),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: authState.isLoading
                ? null
                : () => ref.read(authNotifierProvider.notifier).logout(),
          ),
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
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcoming.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => buildMatchCard(upcoming[i]),
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
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentFinished.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => buildMatchCard(recentFinished[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
