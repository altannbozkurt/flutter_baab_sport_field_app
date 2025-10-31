// lib/features/matches/widgets/match_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Maçları listelemek için kullanılan ana kart widget'ı.
/// Bu widget, home_screen.dart dosyasından taşındı ve dışarıdan kullanılabilir hale getirildi.
class MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool isUpcoming;

  const MatchCard({super.key, required this.match, required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    // --- Verileri ayrıştıralım
    final String? matchId = match['match_id'] as String?;
    final String? fieldName = match['field_name'] ?? 'Bilinmeyen Saha';
    final String? startTimeStr = match['match_start_time'] as String?;
    final String? formatStr = match['match_format'] as String?;
    final int currentPlayers =
        int.tryParse(match['participantCount']?.toString() ?? '0') ?? 0;

    // --- Tarih formatlama (Amerika 'en_US' formatında)
    String formattedDate = 'Tarih Bilinmiyor';
    String formattedTime = 'Saati Yok';
    if (startTimeStr != null) {
      try {
        final startTimeLocal = DateTime.parse(startTimeStr).toLocal();
        // Amerika için format: "October 30"
        formattedDate = DateFormat('MMMM dd', 'en_US').format(startTimeLocal);
        // Amerika için format: "9:44 PM"
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. & 2. BÖLÜMLER: Info Sekmesine Giden Tıklama Alanı ---
          GestureDetector(
            behavior: HitTestBehavior.opaque,
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
                      // _StatusChip'i 'StatusChip' olarak değiştirdik
                      StatusChip(isUpcoming: isUpcoming),
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
                      // _InfoIconText'i 'InfoIconText' olarak değiştirdik
                      InfoIconText(
                        icon: Icons.calendar_today_outlined,
                        text: formattedDate,
                      ),
                      const SizedBox(width: 16),
                      InfoIconText(
                        icon: Icons.access_time_outlined,
                        text: formattedTime,
                      ),
                      const SizedBox(width: 16),
                      InfoIconText(
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

                // --- 'Rate & Review' Tıklama Alanı ---
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
                // Düzeltme: .withValues() yerine .withOpacity()
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

/// Durum (Yaklaşan/Bitti) etiketini oluşturan widget
class StatusChip extends StatelessWidget {
  final bool isUpcoming;
  const StatusChip({super.key, required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    // Amerikalı kullanıcı için etiketleri İngilizce yapalım
    final color = isUpcoming ? Colors.blue : Colors.green;
    final label = isUpcoming ? 'Upcoming' : 'Finished';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // Düzeltme: .withValues() yerine .withOpacity()
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

/// İkon + Metin (Tarih, Saat, Format) oluşturan widget
class InfoIconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoIconText({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sizin kodunuzda 'color' ve 'size' yoktu, eklendi.
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            // Sizin kodunuzda 'color' vardı, temanıza göre ayarlandı.
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
