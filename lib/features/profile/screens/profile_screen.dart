// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/models/badge.dart' as models;
import 'package:flutter_baab_sport_field_app/models/user_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/features/profile/providers/profile_provider.dart';
import 'package:flutter_baab_sport_field_app/models/player_profile.dart';
import 'package:flutter_baab_sport_field_app/models/user.dart';
import 'package:go_router/go_router.dart';

// Ana Profil Ekranı Widget'ı
class ProfileScreen extends ConsumerWidget {
  final String? userId; // Opsiyonel userId parametresi

  const ProfileScreen({this.userId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Veri ve Durum Yönetimi
    final currentUser = ref.watch(authNotifierProvider).currentUser;
    final targetUserId = userId ?? currentUser?.id;

    if (targetUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('User ID not found.')),
      );
    }

    final profileAsyncValue = ref.watch(userProfileByIdProvider(targetUserId));
    final bool isMyProfile = userId == null || userId == currentUser?.id;

    // 2. Ana Scaffold
    return Scaffold(
      appBar: AppBar(
        title: Text(
          profileAsyncValue.maybeWhen(
            data: (user) => user.fullName.isNotEmpty
                ? user.fullName
                : (isMyProfile ? 'My Profile' : 'Profile'),
            orElse: () => (isMyProfile ? 'My Profile' : 'Profile'),
          ),
        ),
        // 3-Nokta Menüsü (Aynen kalıyor)
        actions: [
          if (isMyProfile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    final currentUserData = profileAsyncValue.asData?.value;
                    if (currentUserData != null) {
                      context.go('/profile/edit', extra: currentUserData);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile data not yet loaded.'),
                        ),
                      );
                    }
                    break;
                  case 'settings':
                    // TODO: Ayarlar ekranı eklenebilir
                    break;
                  case 'logout':
                    ref.read(authNotifierProvider.notifier).logout();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit Profile'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Settings'),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red[700]),
                    title: Text(
                      'Log Out',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: profileAsyncValue.when(
        // --- Yükleniyor ---
        loading: () => const Center(child: CircularProgressIndicator()),
        // --- Hata ---
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading profile:\n${error.toString().replaceFirst("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      ref.refresh(userProfileByIdProvider(targetUserId)),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        // --- Veri Başarıyla Geldi ---
        data: (user) {
          final PlayerProfile? profile = user.playerProfile;
          if (profile == null) {
            return const Center(child: Text('Player profile not found.'));
          }
          final List<UserBadge> badges = user.userBadges;

          // --- DÜZELTME: Basit Column ve Expanded Yapısı ---
          return DefaultTabController(
            length: 2, // 2 Sekme: Stats ve Badges
            child: Column(
              children: [
                // 1. Üst Kısım: Oyuncu Kartı (Sabit)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: PlayerCardWidget(profile: profile, user: user),
                ),
                // 2. Sekme Başlıkları (Sabit)
                TabBar(
                  tabs: [
                    const Tab(text: 'Stats'),
                    Tab(text: 'Badges (${badges.length})'),
                  ],
                ),
                // 3. Sekme İçerikleri (Kalan alanı doldurur ve kaydırılabilir olur)
                Expanded(
                  child: TabBarView(
                    children: [
                      // --- Sekme 1: Stats (Güvenilirlik) ---
                      _buildStatsTab(context, profile),
                      // --- Sekme 2: Badges (Rozetler) ---
                      _buildBadgesTab(context, badges),
                    ],
                  ),
                ),
              ],
            ),
          );
          // --- DÜZELTME BİTTİ ---
        },
      ),
    );
  }

  // --- Stats (Güvenilirlik) Sekmesi ---
  // --- GÜNCELLENMİŞ: Stats (Güvenilirlik) Sekmesi ---
  // Kaydırma sorununu çözmek için SingleChildScrollView kaldırıldı.
  Widget _buildStatsTab(BuildContext context, PlayerProfile profile) {
    return GridView.count(
      padding: const EdgeInsets.all(16.0), // Kaydırılabilir alana padding
      crossAxisCount: 2,
      crossAxisSpacing: 12, // Kartlar arası boşluk
      mainAxisSpacing: 12, // Kartlar arası boşluk
      childAspectRatio: 1.7, // En/boy oranı (1.8'den 1.7'ye çekildi)
      // shrinkWrap ve physics kaldırıldı, çünkü TabBarView zaten kaydırmayı yönetiyor.
      children: [
        _buildReliabilityCard(
          context: context,
          title: 'Participation Rate',
          value: '${profile.participationRate.toStringAsFixed(1)}%',
          icon: Icons.check_circle_outline,
          color: Colors.greenAccent.shade700,
        ),
        _buildReliabilityCard(
          context: context,
          title: 'Cancellation Rate',
          value: '${profile.cancellationRate.toStringAsFixed(1)}%',
          icon: Icons.cancel_outlined,
          color: Colors.orangeAccent.shade700,
        ),
        _buildReliabilityCard(
          context: context,
          title: 'No-Show Count',
          value: profile.noShowRate.toInt().toString(),
          icon: Icons.disabled_by_default_outlined,
          color: Colors.redAccent.shade700,
        ),
        _buildReliabilityCard(
          context: context,
          title: 'Fair Play Score',
          value: profile.fairPlayScore.toString(),
          icon: Icons.sports_soccer,
          color: Colors.blueAccent.shade700,
        ),
      ],
    );
  }

  // --- Badges (Rozetler) Sekmesi ---
  // --- GÜNCELLENMİŞ: Badges (Rozetler) Sekmesi ---
  Widget _buildBadgesTab(BuildContext context, List<UserBadge> badges) {
    if (badges.isEmpty) {
      return const Center(
        child: Text(
          'No badges earned yet.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    // GridView yerine ListView kullanıyoruz
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index].badge;
        // Yeni, modernize edilmiş _BadgeWidget'ı çağır
        return _BadgeWidget(badge: badge);
      },
    );
  }

  // Güvenilirlik kartlarını oluşturan yardımcı widget
  // --- GÜNCELLENMİŞ: Modern Güvenilirlik Kartı ---
  Widget _buildReliabilityCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final theme = Theme.of(context);
    // Kartın ana rengini belirle (örn: yeşil, turuncu, kırmızı)
    final mainColor = color ?? theme.colorScheme.primary;

    return Card(
      color:
          theme.colorScheme.surfaceContainer, // Hafifçe daha koyu bir arka plan
      elevation: 0, // Düz (flat) tasarım
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Hafif bir kenarlık (border) ekliyoruz
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10.0,
          vertical: 16.0,
        ), // İç boşluğu artırdık
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // İçeriği üste ve alta yasla
          children: [
            // 1. Üst Kısım: İkon ve Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant, // Daha soluk bir başlık
                    ),
                  ),
                ),
                // İkonu renkli bir daire içine alıyoruz
                Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: mainColor),
                ),
              ],
            ),

            // 2. Alt Kısım: Değer (Value)
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface, // Ana değer rengi
              ),
            ),
          ],
        ),
      ),
    );
  }
} // <-- ProfileScreen class'ı burada biter

// --- _SliverTabBarDelegate Class'ı ARTIK GEREKLİ DEĞİL VE SİLİNDİ ---

// --- Oyuncu Kartı Widget'ı (Aynen kalıyor) ---
// --- YENİLENMİŞ, MODERN OYUNCU KARTI WIDGET'I ---
class PlayerCardWidget extends StatelessWidget {
  final User user;
  final PlayerProfile profile;
  const PlayerCardWidget({
    required this.user,
    required this.profile,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Kart Renklerini ve Gradient'larını Ayarla
    Color baseColor;
    List<Color> gradientColors;

    switch (profile.cardType.toLowerCase()) {
      case 'gold':
        baseColor = const Color(0xFFD4AF37); // Altın
        gradientColors = [const Color(0xFFDAA520), const Color(0xFFB8860B)];
        break;
      case 'silver':
        baseColor = const Color(0xFFC0C0C0); // Gümüş
        gradientColors = [const Color(0xFFC0C0C0), const Color(0xFFA9A9A9)];
        break;
      case 'bronze':
      default:
        baseColor = const Color(0xFFCD7F32); // Bronz
        gradientColors = [const Color(0xFFCD7F32), const Color(0xFF8B4513)];
    }

    final displayName = user.fullName.isNotEmpty ? user.fullName : "No Name";

    return Card(
      clipBehavior: Clip.antiAlias, // Gradient'ın köşelerden taşmaması için
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- 1. BÖLÜM: Profil, İsim ve Rating ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol Taraf: Avatar ve İsim
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: user.displayImageUrl.startsWith('http')
                          ? NetworkImage(user.displayImageUrl)
                          : const AssetImage(
                                  'assets/images/default_profile.jpg',
                                )
                                as ImageProvider,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  const Shadow(
                                    blurRadius: 2,
                                    color: Colors.black38,
                                  ),
                                ],
                              ),
                        ),
                        Text(
                          profile.preferredPosition ?? 'Player',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ],
                ),
                // Sağ Taraf: Rating
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      profile.overallRating.toString(),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          const Shadow(blurRadius: 2, color: Colors.black38),
                        ],
                      ),
                    ),
                    Text(
                      profile.cardType.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white30, thickness: 0.5),
            const SizedBox(height: 10),

            // --- 2. BÖLÜM: Statlar (Renkli) ---
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8, // Kutuları daha karemsi yapar
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                // Stat renklerini FIFA'ya benzer yapalım
                _buildStatItem(
                  'PAC',
                  profile.statPac,
                  const Color(0xFF00BFA5),
                ), // Teal
                _buildStatItem(
                  'SHO',
                  profile.statSho,
                  const Color(0xFF55D15A),
                ), // Green
                _buildStatItem(
                  'PAS',
                  profile.statPas,
                  const Color(0xFF4FC3F7),
                ), // Blue
                _buildStatItem(
                  'DRI',
                  profile.statDri,
                  const Color(0xFFFFB300),
                ), // Amber
                _buildStatItem(
                  'DEF',
                  profile.statDef,
                  const Color(0xFF7E57C2),
                ), // Purple
                _buildStatItem(
                  'PHY',
                  profile.statPhy,
                  const Color(0xFFF06292),
                ), // Pink
              ],
            ),

            // --- 3. BÖLÜM: Diğer Bilgiler ---
            if (profile.preferredFoot != null) ...[
              const SizedBox(height: 10),
              _buildInfoChip(
                context,
                Icons.compare_arrows_rounded, // Ayak için ikon
                'Preferred Foot: ${profile.preferredFoot}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  // YENİ: Renkli statları gösteren yardımcı widget
  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
            shadows: [
              Shadow(blurRadius: 2.0, color: Colors.black.withOpacity(0.5)),
            ],
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // YENİ: İkonlu bilgi çipi gösteren yardımcı widget
  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// --- Rozet Widget'ı (Aynen kalıyor) ---
class _BadgeWidget extends StatelessWidget {
  final models.Badge badge;
  const _BadgeWidget({required this.badge, super.key});

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'gold':
        return Colors.amber.shade700;
      case 'silver':
        return Colors.grey.shade400;
      case 'bronze':
      default:
        return Colors.brown.shade800;
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'gold':
        return Icons.workspace_premium;
      case 'silver':
        return Icons.workspace_premium_outlined;
      case 'bronze':
      default:
        return Icons.shield;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColor = _getTierColor(badge.tier);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer, // Stats kartlarıyla aynı renk
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12.0), // Kartlar arası boşluk
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          // ListTile yerine Row kullanıyoruz
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sol Taraf: İkon
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10), // Daire yerine kare
              ),
              child: badge.iconUrl != null && badge.iconUrl!.startsWith('http')
                  ? Image.network(
                      badge.iconUrl!,
                      width: 32, // İkonu biraz büyüttük
                      height: 32,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        _getTierIcon(badge.tier),
                        size: 32,
                        color: tierColor,
                      ),
                    )
                  : Icon(_getTierIcon(badge.tier), size: 32, color: tierColor),
            ),
            const SizedBox(width: 16),
            // 2. Sağ Taraf: Metin (Yazıların sığması için Expanded)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    // maxLines kaldırıldı, böylece açıklama istediği kadar uzayabilir
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
