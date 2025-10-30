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
import 'package:flutter_baab_sport_field_app/models/badge.dart';

// TODO: User modelini de import edebiliriz (isim vb. için AuthState'ten almak yerine)

// Placeholder Oyuncu Kartı Widget'ı (Daha sonra güzelleştirilecek)
class PlayerCardWidget extends StatelessWidget {
  final User user; // Yeni: User modelini al
  final PlayerProfile profile;
  const PlayerCardWidget({
    required this.user,
    required this.profile,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Kart rengini belirle
    Color cardColor = Colors.brown.shade800; // Bronze
    if (profile.cardType == 'silver') cardColor = Colors.grey.shade700;
    if (profile.cardType == 'gold') cardColor = Colors.yellow.shade800;

    // --- İsim Boş mu Kontrolü ---
    final displayName = user.fullName.isNotEmpty ? user.fullName : "İsim Yok";
    // --- Kontrol Bitti ---

    // --- Debug için print ekleyelim ---
    debugPrint(
      "PlayerCardWidget build: user.fullName = '${user.fullName}', displayName = '$displayName'",
    );
    // --- Print Bitti ---

    return Card(
      color: cardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        width: double.infinity, // Ekranı kaplasın
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40, // Daha büyük bir avatar
              backgroundImage: user.displayImageUrl.startsWith('http')
                  ? NetworkImage(user.displayImageUrl)
                  : const AssetImage(
                      'assets/images/default_profile.jpg',
                    ), // User modelindeki getter'ı kullan
              backgroundColor:
                  Colors.white24, // Yüklenirken veya hata durumunda arka plan
            ),
            const SizedBox(height: 10),
            Text(
              displayName, // Kullanıcının tam adı
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'OYUNCU KARTI',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  profile.overallRating.toString(), // Ana reyting
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  profile.cardType
                      .toUpperCase(), // KART TÜRÜ (BRONZE, SILVER, GOLD)
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Statları Grid ile gösterelim
            GridView.count(
              crossAxisCount: 3, // Yan yana 3 stat
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5, // Kutuların en/boy oranı
              children: [
                _buildStatItem('HIZ', profile.statPac),
                _buildStatItem('ŞUT', profile.statSho),
                _buildStatItem('PAS', profile.statPas),
                _buildStatItem('DRİ', profile.statDri),
                _buildStatItem('DEF', profile.statDef),
                _buildStatItem('FİZ', profile.statPhy),
              ],
            ),
            const SizedBox(height: 10),
            // Favori Ayak / Pozisyon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'Ayak: ${profile.preferredFoot ?? 'Secilmedi'}',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  'Pozisyon: ${profile.preferredPosition ?? 'Secilmedi'}',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Statları gösteren yardımcı widget
  Widget _buildStatItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }
}

// Ana Profil Ekranı Widget'ı
class ProfileScreen extends ConsumerWidget {
  final String? userId; // Opsiyonel userId parametresi

  // Eğer userId null ise kendi profilimizi gösteririz
  const ProfileScreen({this.userId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Giriş yapmış mevcut kullanıcıyı al (AppBar ve kendi profilimiz için)
    final currentUser = ref.watch(authNotifierProvider).currentUser;
    // Gösterilecek olan userId (ya parametreden gelen ya da mevcut kullanıcı)
    final targetUserId = userId ?? currentUser?.id;

    // Eğer gösterilecek bir ID yoksa (ne parametre ne de mevcut kullanıcı) hata göster
    if (targetUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: const Center(child: Text('Kullanıcı ID\'si bulunamadı.')),
      );
    }

    // Hangi provider'ı dinleyeceğimizi belirle
    // Eğer başkasının profiline bakıyorsak userProfileByIdProvider'ı,
    // kendi profilimize bakıyorsak userProfileProvider'ı (veya yine ById'yi kendi ID'mizle) kullanabiliriz.
    // userProfileByIdProvider hem User hem PlayerProfile döndürdüğü için daha iyi.
    final profileAsyncValue = ref.watch(userProfileByIdProvider(targetUserId));

    // Kendi profilimiz mi? (Logout butonu için)
    final bool isMyProfile = userId == null || userId == currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        // Başlık, veri yüklendiğinde kullanıcının adını göstersin
        title: Text(
          profileAsyncValue.maybeWhen(
            data: (user) => user.fullName.isNotEmpty
                ? user.fullName
                : (isMyProfile ? 'Profilim' : 'Profil'),
            orElse: () => (isMyProfile ? 'Profilim' : 'Profil'),
          ),
        ),
        actions: [
          // Sadece kendi profilimizdeyse Logout butonunu göster
          if (isMyProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Çıkış Yap',
              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          // Sadece kendi profilimizdeyse Düzenle butonu göster (ileride)
          if (isMyProfile)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Profili Düzenle',
              onPressed: () {
                // Düzenleme ekranına git
                // Mevcut User verisini parametre olarak gönderebiliriz (opsiyonel ama iyi olur)
                final currentUserData = profileAsyncValue.asData?.value;
                if (currentUserData != null) {
                  context.go(
                    '/profile/edit',
                    extra: currentUserData,
                  ); // extra ile veriyi gönder
                } else {
                  // Veri henüz yüklenmediyse veya hata varsa uyarı göster
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profil verileri henüz yüklenmedi.'),
                    ),
                  );
                }
              },
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
                  'Profil yüklenirken hata oluştu:\n${error.toString().replaceFirst("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  // Provider'ı yenilemeyi dene
                  onPressed: () => ref.refresh(userProfileProvider),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
        // --- Veri Başarıyla Geldi ---
        data: (user) {
          // PlayerProfile'ı User nesnesinden al
          final PlayerProfile? profile = user.playerProfile;

          // Eğer profil verisi yoksa (olmamalı ama kontrol edelim)
          if (profile == null) {
            return const Center(child: Text('Oyuncu profili bulunamadı.'));
          }
          // --- YENİ: Rozet listesini al ---
          final List<UserBadge> badges = user.userBadges;
          // --- BİTTİ ---
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Öğeleri genişlet
              children: [
                // --- Oyuncu Kartı ---
                PlayerCardWidget(profile: profile, user: user),
                const SizedBox(height: 24),

                // --- Güvenilirlik İstatistikleri (Uber Tarzı) ---
                Text(
                  'Güvenilirlik',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.8, // Kartların en/boy oranı
                  children: [
                    _buildReliabilityCard(
                      context: context,
                      title: 'Katılım Oranı',
                      value:
                          '${profile.participationRate.toStringAsFixed(1)}%', // Ondalıklı göster
                      icon: Icons.check_circle_outline,
                      color: Colors.greenAccent.shade700,
                    ),
                    _buildReliabilityCard(
                      context: context,
                      title: 'İptal Oranı',
                      value: '${profile.cancellationRate.toStringAsFixed(1)}%',
                      icon: Icons.cancel_outlined,
                      color: Colors.orangeAccent.shade700,
                    ),
                    _buildReliabilityCard(
                      context: context,
                      title:
                          'Gelmedi Sayısı', // Oran yerine sayı daha anlamlı olabilir
                      value: profile.noShowRate
                          .toInt()
                          .toString(), // Tam sayı göster
                      icon: Icons.disabled_by_default_outlined,
                      color: Colors.redAccent.shade700,
                    ),
                    _buildReliabilityCard(
                      context: context,
                      title: 'Fair Play Puanı',
                      value: profile.fairPlayScore.toString(),
                      icon: Icons.sports_soccer, // Veya handshake ikonu
                      color: Colors.blueAccent.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Kazanılan Rozetler ---
                // --- GÜNCELLENMİŞ Rozetler Bölümü ---
                Text(
                  'Kazanılan Rozetler (${badges.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (badges.isEmpty)
                  const Center(
                    child: Text(
                      'Henüz kazanılmış rozet yok.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  // Rozetleri yatay kaydırılabilir bir listede göster
                  SizedBox(
                    height: 100, // Rozet widget'ının yüksekliği
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: badges.length,
                      itemBuilder: (context, index) {
                        // UserBadge -> Badge nesnesini al
                        final badge = badges[index].badge;
                        // Yeni BadgeWidget'ımızı çağır
                        return _BadgeWidget(badge: badge);
                      },
                    ),
                  ),

                const SizedBox(height: 24),

                // TODO: Profili Düzenle Butonu
              ],
            ),
          );
        },
      ),
    );
  }

  // Güvenilirlik kartlarını oluşturan yardımcı widget
  Widget _buildReliabilityCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest, // Kart arka planı
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // İçeriği dağıt
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                Icon(
                  icon,
                  size: 18,
                  color: color ?? Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// --- YENİ YARDIMCI WIDGET: _BadgeWidget ---
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
        return Icons.workspace_premium; // Veya Icons.emoji_events
      case 'silver':
        return Icons.workspace_premium_outlined;
      case 'bronze':
      default:
        return Icons.shield; // Varsayılan ikon
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor(badge.tier);

    return Tooltip(
      // Üzerine gelince açıklamayı göster
      message: "${badge.name}\n${badge.description}",
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      preferBelow: false,
      child: Container(
        width: 90, // Sabit genişlik
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tierColor.withOpacity(0.5)),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // İkon (icon_url varsa NetworkImage, yoksa tier'a göre varsayılan ikon)
            badge.iconUrl != null && badge.iconUrl!.startsWith('http')
                ? Image.network(
                    badge.iconUrl!,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      _getTierIcon(badge.tier),
                      size: 40,
                      color: tierColor,
                    ),
                  )
                : Icon(_getTierIcon(badge.tier), size: 40, color: tierColor),
            const SizedBox(height: 8),
            // Rozet Adı
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
