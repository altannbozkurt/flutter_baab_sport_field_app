// lib/features/matches/widgets/matches_list_view_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/core/providers/location_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/matches_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/widgets/match_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class MatchesListViewWidget extends ConsumerWidget {
  const MatchesListViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bu widget, SADECE maçlar ve konum ile ilgilenir
    final matchesState = ref.watch(matchesNotifierProvider);
    final locationState = ref.watch(locationNotifierProvider);

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
                      ? 'Open Settings' // Amerika için
                      : 'Try Again', // Amerika için
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Yüklenme Durumu (Konum veya Maçlar yükleniyor)
    if (matchesState.isLoading || locationState.position == null) {
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
                'Could not load matches:\n${matchesState.errorMessage}', // Amerika için
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    ref.read(matchesNotifierProvider.notifier).refreshMatches(),
                child: const Text('Try Again'), // Amerika için
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
            const Text('No public matches found near you.'), // Amerika için
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.go('/create-match');
              },
              child: const Text('Create the First Match!'), // Amerika için
            ),
          ],
        ),
      );
    }

    // 5. Maç Listesi Dolu -> Sizin kodunuzdaki bölümleme mantığı
    final now =
        DateTime.now(); // .toUtc() kaldırıldı, .parse().toLocal() kullanılacak
    final upcoming = <Map<String, dynamic>>[];
    final recentFinished = <Map<String, dynamic>>[];

    for (final match in matchesState.matches) {
      final String? startTimeStr = match['match_start_time'] as String?;
      DateTime? startLocal;
      if (startTimeStr != null) {
        try {
          // Gelen UTC tarihi parse et ve telefonun lokaline çevir
          startLocal = DateTime.parse(startTimeStr).toLocal();
        } catch (e) {
          debugPrint('start_time parse hatası: $e');
        }
      }

      if (startLocal == null || startLocal.isAfter(now)) {
        upcoming.add(match);
      } else {
        recentFinished.add(match);
      }
    }

    // Sıralamalar (Sizin kodunuzla aynı, toLocal() eklendi)
    upcoming.sort((a, b) {
      final as = DateTime.tryParse(a['match_start_time'] ?? '')?.toLocal();
      final bs = DateTime.tryParse(b['match_start_time'] ?? '')?.toLocal();
      if (as == null && bs == null) return 0;
      if (as == null) return 1;
      if (bs == null) return -1;
      return as.compareTo(bs); // Yaklaşan: Eskiden yeniye
    });
    recentFinished.sort((a, b) {
      final as = DateTime.tryParse(a['match_start_time'] ?? '')?.toLocal();
      final bs = DateTime.tryParse(b['match_start_time'] ?? '')?.toLocal();
      if (as == null && bs == null) return 0;
      if (as == null) return 1;
      if (bs == null) return -1;
      return bs.compareTo(as); // Biten: Yeniden eskiye
    });

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(matchesNotifierProvider.notifier).refreshMatches(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 96.0), // FAB için boşluk
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (upcoming.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'Upcoming', // Amerika için
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcoming.length,
                  itemBuilder: (_, i) =>
                      MatchCard(match: upcoming[i], isUpcoming: true),
                ),
              ],
              if (recentFinished.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    'Recently Finished', // Amerika için
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentFinished.length,
                  itemBuilder: (_, i) =>
                      MatchCard(match: recentFinished[i], isUpcoming: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
