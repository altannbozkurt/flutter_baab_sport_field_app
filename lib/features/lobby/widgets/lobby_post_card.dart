// lib/features/lobby/widgets/lobby_post_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/models/lobby_posting.dart';
import 'package:intl/intl.dart';

class LobbyPostCard extends StatelessWidget {
  final LobbyPosting post;
  const LobbyPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium;

    final bool isPlayerWanted = post.type == 'PLAYER_WANTED';
    final cardColor = isPlayerWanted
        ? Colors.blue.shade800.withOpacity(0.1)
        : Colors.green.shade800.withOpacity(0.1);
    final icon = isPlayerWanted
        ? const Icon(Icons.person_add, color: Colors.blue)
        : const Icon(Icons.group_add, color: Colors.green);

    // Amerika için etiketler
    final typeText = isPlayerWanted
        ? "${post.playersNeeded ?? 1} Player(s) Wanted"
        : "Opponent Team Wanted (${post.teamSize}v${post.teamSize})";

    return Card(
      elevation: 2,
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    post.title,
                    style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              typeText,
              style: subtitleStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (post.field != null)
              _buildInfoRow(Icons.location_on, post.field!.name),

            // Zaman Bilgisi (Amerika formatı)
            _buildInfoRow(
              Icons.calendar_today,
              // Format: "Oct 30, 9:44 PM"
              DateFormat(
                'MMM d, h:mm a',
                'en_US',
              ).format(post.matchTime.toLocal()),
            ),

            _buildInfoRow(
              Icons.person,
              "Posted by: ${post.creator.fullName}", // Amerika için
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
