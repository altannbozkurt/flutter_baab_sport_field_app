// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/matches_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/lobby/providers/lobby_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/widgets/matches_list_view_widget.dart';
import 'package:flutter_baab_sport_field_app/features/lobby/widgets/lobby_list_view_widget.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. TabController'ı oluştur (2 sekmeli)
    final tabController = useTabController(initialLength: 2);

    // 2. Aktif sekmenin index'ini izle (FAB'ı değiştirmek için)
    final activeTabIndex = useState(0);

    // 3. TabController'ın değişimlerini dinle ve state'i güncelle
    useEffect(() {
      void listener() {
        if (tabController.indexIsChanging) return;
        activeTabIndex.value = tabController.index;
      }

      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    // Aktif sekmeye göre FAB icon ve tooltip'ini belirle
    final fabProps = _getFabProperties(activeTabIndex.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Game'), // Amerika için
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'MATCHES'), // Sizin istediğiniz
            Tab(text: 'LOBBY'), // Sizin istediğiniz
          ],
        ),
        actions: [
          // Yenileme Butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (activeTabIndex.value == 0) {
                // Maçlar sekmesindeysek maçları yenile
                ref.read(matchesNotifierProvider.notifier).refreshMatches();
              } else {
                // Lobi sekmesindeysek lobiyi yenile
                ref.invalidate(openLobbyPostsProvider);
              }
            },
          ),
          // Logout Butonu (Sizin kodunuzdan)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: tabController,
        // Sekme içeriklerini dışarıdan çağır
        children: const [
          // Sekme 1: Maçlar (Konum izni, yükleme ve listeyi kendi içinde halleder)
          MatchesListViewWidget(),

          // Sekme 2: Lobi (Yükleme ve listeyi kendi içinde halleder)
          LobbyListViewWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aktif sekmeye göre doğru ekrana yönlendir
          if (activeTabIndex.value == 0) {
            // 1. Sekme (Maçlar) aktif: Maç Oluştur'a git
            context.go('/create-match');
          } else {
            // 2. Sekme (Lobi) aktif: Lobi İlanı Ver'e git
            // TODO: 'create-lobby-post' rotasını GoRouter'a ekleyip ekranı oluşturun
            context.go('/create-lobby-post');
            // context.go('/create-lobby-post');

            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('Create Lobby Post screen is coming soon!'),
            //   ),
            // );
          }
        },
        tooltip: fabProps.tooltip,
        child: Icon(fabProps.icon),
      ),
    );
  }
}

// FAB özelliklerini tutan yardımcı sınıf
class FabProperties {
  final IconData icon;
  final String tooltip;
  FabProperties({required this.icon, required this.tooltip});
}

// Aktif sekmeye göre doğru Icon ve Tooltip'i döndüren fonksiyon
FabProperties _getFabProperties(int index) {
  switch (index) {
    case 0: // Maçlar
      return FabProperties(
        icon: Icons.add,
        tooltip: 'Create Match',
      ); // Amerika için
    case 1: // Lobi
      return FabProperties(
        icon: Icons.campaign,
        tooltip: 'Create Post',
      ); // Amerika için
    default:
      return FabProperties(icon: Icons.add, tooltip: 'Create Match');
  }
}
