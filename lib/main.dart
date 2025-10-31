// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/features/lobby/screens/create_lobby_post_screen.dart';
import 'package:flutter_baab_sport_field_app/features/profile/screens/edit_profile_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';

// Ekranlarımızı import edelim
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/matches/screens/create_match_screen.dart'; // Yeni ekran
import 'features/profile/screens/profile_screen.dart'; // Yeni ekran
import 'widgets/scaffold_with_nav_bar.dart'; // Yeni Scaffold
import 'features/matches/screens/match_detail_screen.dart';
import 'models/user.dart'; // <-- User modelini import et

Future<void> main() async {
  // .env dosyasını yüklediğimizden emin olalım
  WidgetsFlutterBinding.ensureInitialized(); // Flutter binding'lerinin hazır olduğundan emin ol
  await dotenv.load(fileName: ".env");
  runApp(const ProviderScope(child: MyApp()));
}

// Router Provider'ı
final goRouterProvider = Provider<GoRouter>((ref) {
  // Navigasyon için global anahtarlar
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorHomeKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellHome',
  );
  final shellNavigatorCreateKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellCreate',
  );
  final shellNavigatorProfileKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellProfile',
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    //initialLocation: '/login', // Uygulama açıldığında ilk gidilecek yer

    // Auth state değişikliklerini dinle ve yönlendirmeyi tetikle
    refreshListenable: GoRouterRefreshStream(
      // Notifier'ın state stream'ini dinle
      ref.watch(authNotifierProvider.notifier).stream,
    ),

    // Yönlendirme mantığı
    redirect: (BuildContext context, GoRouterState state) {
      final location = state.uri.toString();
      final bool loggingIn = location == '/login' || location == '/register';

      // En güncel authState'i oku
      final authState = ref.read(authNotifierProvider);
      debugPrint(
        '[GoRouter.redirect] location=$location isLoading=${authState.isLoading} isAuthed=${authState.isAuthenticated}',
      );

      // 1️⃣ Yükleniyorsa (ilk açılışta token kontrolü vb.) bekle
      if (authState.isLoading) return null;

      // 2️⃣ Giriş yapmamışsa ve login/register ekranında değilse -> /login'e gönder
      if (!authState.isAuthenticated && !loggingIn) {
        debugPrint('[GoRouter.redirect] -> /login');
        return '/login';
      }

      // 3️⃣ Giriş yapmışsa ve login/register ekranına gitmeye çalışıyorsa -> Ana ekrana (/) gönder
      if (authState.isAuthenticated && loggingIn) {
        debugPrint('[GoRouter.redirect] -> /');
        return '/';
      }

      // 4️⃣ Diğer tüm durumlarda yönlendirme yapma, olduğu yerde kal
      return null;
    },

    // Rotalar
    routes: <RouteBase>[
      // 1. Ana Navigasyon (BottomNavBar içeren ShellRoute)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // Ana Scaffold'u (NavBar içeren) döndür
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // --- Branch 1: Ana Sayfa Sekmesi ---
          StatefulShellBranch(
            navigatorKey: shellNavigatorHomeKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/', // Bu sekmenin ana rotası
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
                // TODO: Ana sayfa sekmesinden gidilebilecek alt rotalar (örn: Maç Detayı) buraya eklenebilir
                routes: <RouteBase>[
                  GoRoute(
                    path:
                        'matches/:matchId', // '/' rotasının alt rotası: /matches/:matchId
                    // Navigator'ı root'a ayarlayarak NavBar'ı gizleyebiliriz (isteğe bağlı)
                    // parentNavigatorKey: rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) {
                      // URL'den matchId parametresini al
                      final matchId = state.pathParameters['matchId'];
                      final tab = state.uri.queryParameters['tab'];
                      // Eğer ID yoksa hata ekranı göster (veya ana sayfaya yönlendir)
                      if (matchId == null)
                        return const Text('Maç ID bulunamadı!');
                      return MatchDetailScreen(
                        matchId: matchId,
                        initialTabName: tab,
                      ); // Ekrana ID'yi gönder
                    },
                  ),
                ],
              ),
            ],
          ),

          // --- Branch 2: Maç Oluştur Sekmesi ---
          StatefulShellBranch(
            navigatorKey: shellNavigatorCreateKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/create-match', // Bu sekmenin ana rotası
                builder: (BuildContext context, GoRouterState state) =>
                    const CreateMatchScreen(),
              ),
              GoRoute(
                path: '/create-lobby-post', // YENİ LOBİ İLANI ROTASI
                builder: (context, state) => const CreateLobbyPostScreen(),
              ),
            ],
          ),

          // --- Branch 3: Profil Sekmesi ---
          StatefulShellBranch(
            navigatorKey: shellNavigatorProfileKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/profile', // Bu sekmenin ana rotası
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path:
                        'edit', // '/profile' rotasının alt rotası: /profile/edit
                    // parentNavigatorKey: rootNavigatorKey, // İstersen NavBar'ı gizler
                    builder: (BuildContext context, GoRouterState state) {
                      // ProfileScreen'den gönderilen User verisini al
                      final User? initialUser = state.extra as User?;
                      if (initialUser == null) {
                        // Eğer veri gelmediyse (olmamalı ama...) hata göster veya geri yönlendir
                        return const Scaffold(
                          body: Center(
                            child: Text(
                              'Düzenlenecek profil verisi bulunamadı.',
                            ),
                          ),
                        );
                      }
                      return EditProfileScreen(
                        initialUser: initialUser,
                      ); // Ekrana veriyi gönder
                    },
                  ),
                ],
                // TODO: Profil sekmesinden gidilebilecek alt rotalar (örn: Ayarlar) buraya eklenebilir
              ),
            ],
          ),
        ],
      ),

      // 2. Shell DIŞINDAKI Rotalar (Login / Register)
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // 3. Kullanıcı profili (başkasının profili) - geçici olarak ProfileScreen
      GoRoute(
        path: '/users/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          if (userId == null) {
            return const Scaffold(/*...*/); // Hata ekranı
          }
          // ProfileScreen'e userId'yi gönder
          return ProfileScreen(userId: userId);
        },
      ),

      // --- YENİ ROTA BİTTİ ---
    ],
    // Hata durumunda gösterilecek sayfa (opsiyonel)
    // errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
});

// GoRouter'ın state değişikliklerini dinlemesi için yardımcı sınıf
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
      onError: (error) =>
          print("Refresh Stream Error: $error"), // Hata loglaması eklendi
      cancelOnError: false, // Hata olsa bile dinlemeye devam et
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// MyApp widget'ı
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // goRouterProvider'ı dinle
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Paslaş App',
      theme: ThemeData(
        brightness: Brightness.dark, // Koyu tema
        colorScheme: ColorScheme.fromSeed(
          // Modern renk şeması
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false, // Debug banner'ını kaldır
      // Router'ı kullan
      routerConfig: router,
    );
  }
}
