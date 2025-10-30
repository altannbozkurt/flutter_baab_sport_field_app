// lib/widgets/scaffold_with_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// StatefulShellNavigation ana içerik widget'ını tutar
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ana içerik (seçilen sekmeye göre değişir)
      body: navigationShell,

      // Alt Navigasyon Barı
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Maç Oluştur',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        currentIndex: navigationShell.currentIndex, // Aktif sekme index'i
        onTap: (int index) =>
            _onTap(context, index), // Tıklanınca sekme değiştir
        // Aktif rengi tema'dan alabilir veya belirleyebiliriz
        // selectedItemColor: Theme.of(context).primaryColor,
        // unselectedItemColor: Colors.grey,
      ),
    );
  }

  // Sekmeye tıklandığında GoRouter'ı kullanarak ilgili sekmeye git
  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      // Eğer kullanıcı zaten o sekmedeyse ve tekrar tıklarsa
      // o sekmenin en başına (ilk sayfasına) dönmesini sağlar.
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
