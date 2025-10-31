// lib/features/lobby/widgets/lobby_list_view_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_baab_sport_field_app/features/lobby/providers/lobby_provider.dart';
import 'package:flutter_baab_sport_field_app/features/lobby/widgets/lobby_post_card.dart';

class LobbyListViewWidget extends ConsumerWidget {
  const LobbyListViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyPostsAsync = ref.watch(openLobbyPostsProvider);

    return lobbyPostsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text('No active lobby posts found.'), // Amerika için
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            return ref.refresh(openLobbyPostsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 96,
            ), // FAB için boşluk
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return InkWell(
                onTap: () {
                  // TODO: Lobi ilan detay sayfasına git
                  // context.go('/lobby/${post.id}');
                },
                child: LobbyPostCard(post: post),
              );
            },
          ),
        );
      },
    );
  }
}
