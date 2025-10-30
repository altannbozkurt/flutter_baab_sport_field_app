// lib/features/matches/widgets/participant_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/models/match_participant.dart';
import 'package:flutter_baab_sport_field_app/models/player_profile.dart'; // Profile modeli için
import 'package:flutter_baab_sport_field_app/models/user.dart'; // User için
import 'package:go_router/go_router.dart'; // GoRouter import

class ParticipantCard extends StatelessWidget {
  final MatchParticipant participant;

  const ParticipantCard({required this.participant, super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = participant.user; // Katılımcının User bilgisi
    // Profil bilgisi user içinde olabilir (backend'den öyle geliyor)
    final PlayerProfile? profile = user?.playerProfile;
    // Kullanıcı bilgisi yoksa boş göster
    // Kullanıcı veya profil bilgisi yoksa basit bir gösterim
    if (user == null || profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(user?.fullName ?? 'Bilinmeyen Katılımcı'),
        ),
      );
    }

    // Kart rengini ve uyumlu metin rengini belirle
    Color cardColor = Colors.brown.shade800; // Bronze
    Color textColor = Colors.white; // Bronze için beyaz
    if (profile.cardType == 'silver') {
      cardColor = Colors.grey.shade400;
      textColor = Colors.black87; // Silver için koyu
    } else if (profile.cardType == 'gold') {
      cardColor = Colors.amber.shade700;
      textColor = Colors.black87; // Gold için koyu
    }
    // --- Pozisyon bilgisini positionRequest'ten al ---
    final String positionText = participant.positionRequest?.isNotEmpty == true
        ? participant.positionRequest! // İstek varsa onu kullan
        : (profile.preferredPosition ??
              '-'); // Yoksa tercih edileni, o da yoksa varsayılanı kullan
    // --- Bitti ---

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: cardColor.withValues(alpha: 0.7),
          width: 1.5,
        ), // Rengi biraz soluklaştıralım
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Kullanıcı profili sayfasına yönlendirme
          context.push('/users/${user.id}');
          //context.go('/users/${user.id}'); // Rota tanımlanınca bu açılacak
          print('Navigating to profile of ${user.id}'); // Geçici log
          // Şimdilik kendi profil sayfamıza gidelim (test için)
          // context.go('/profile');
        },
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: user.displayImageUrl.startsWith('http')
                    ? NetworkImage(user.displayImageUrl)
                    : AssetImage(user.displayImageUrl)
                          as ImageProvider, // AssetImage için cast
                backgroundColor: Colors.grey.shade800, // Yüklenirken arka plan
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.fullName.isNotEmpty
                          ? user.fullName
                          : 'İsimsiz Oyuncu',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ), // Biraz küçülttük
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Reyting (Kart renginde)
                        Text(
                          profile.overallRating.toString(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cardColor, // Kart rengini kullan
                              ),
                        ),
                        Text(
                          ' GEN',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: cardColor.withValues(alpha: 0.8),
                              ),
                        ),
                        const Text(' - '), // Ayraç
                        // Pozisyon
                        Expanded(
                          // Uzun pozisyon adları için
                          child: Text(
                            positionText,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ListTile(
//         leading: CircleAvatar(
//           backgroundImage: user.displayImageUrl.startsWith('http')
//               ? NetworkImage(user.displayImageUrl)
//               : AssetImage(user.displayImageUrl)
//                     as ImageProvider, // AssetImage için cast
//           backgroundColor: Colors.grey.shade800, // Yüklenirken arka plan
//         ),
//         title: Text(
//           user.fullName.isNotEmpty ? user.fullName : 'İsimsiz Oyuncu',
//         ),
//         subtitle: Text(
//           // Profil varsa reytingi ve pozisyonu gösterelim
//           profile != null
//               ? '${profile.overallRating} GEN - $positionText'
//               : 'Profil Yok',
//           style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
//         ),
//         // İsteğe bağlı: trailing'e küçük bir ikon veya bilgi eklenebilir
//         // trailing: Icon(Icons.shield_outlined, size: 16), // Örn: Defans ikonu
//       ),
