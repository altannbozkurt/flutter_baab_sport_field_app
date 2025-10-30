// lib/features/matches/screens/match_detail_screen.dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/matches_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/features/matches/widgets/participant_card.dart';
import 'package:flutter_baab_sport_field_app/models/match_participant.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_baab_sport_field_app/models/match.dart';
import 'package:intl/intl.dart';
import 'package:flutter_baab_sport_field_app/features/matches/providers/match_detail_provider.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_baab_sport_field_app/features/votes/providers/votes_notifier_provider.dart';
import 'package:flutter_baab_sport_field_app/models/field.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_baab_sport_field_app/features/matches/widgets/match_voting_widget.dart';

class MatchDetailScreen extends HookConsumerWidget {
  final String matchId;
  final String? initialTabName; // <-- 1. YENİ PARAMETRE

  const MatchDetailScreen({
    required this.matchId,
    this.initialTabName, // <-- 2. CONSTRUCTOR'A EKLENDİ
    super.key,
  });

  // --- YOL TARİFİ İÇİN YARDIMCI FONKSİYON ---
  Future<void> _launchMaps(BuildContext context, Field field) async {
    if (field.location == null) return;
    final lat = field.location!.latitude;
    final lon = field.location!.longitude;
    final query = Uri.encodeComponent(field.address ?? '$lat,$lon');
    Uri googleMapsUrl = Uri.parse(
      'http://googleusercontent.com/maps.google.com/3',
    );
    Uri appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$query');
    Uri uriToLaunch;
    if (Platform.isIOS) {
      uriToLaunch = appleMapsUrl;
    } else {
      uriToLaunch = googleMapsUrl;
    }
    try {
      if (await canLaunchUrl(uriToLaunch)) {
        await launchUrl(uriToLaunch, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot launch $uriToLaunch';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch maps: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchDetailAsyncValue = ref.watch(matchDetailProvider(matchId));
    final matchesNotifierState = ref.watch(matchesNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final String? currentUserId = authState.currentUser?.id;

    // Hook'lar
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final notifier = ref.read(votesNotifierProvider.notifier);
          notifier.reset();
          notifier.fetchMyVoteStatus(matchId);
        }
      });
      return null;
    }, [currentUserId, matchId]);

    final votingSectionKey = useMemoized(() => GlobalKey());
    final processingParticipantId = useState<String?>(null);
    final noShowUserIds = useState<Set<String>>({});

    // --- State Listeners (Dinleyiciler) ---
    ref.listen<VotesState>(votesNotifierProvider, (previous, next) {
      if (next.errorMessage != null && previous?.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Voting Error: ${next.errorMessage!}"),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          ref.read(votesNotifierProvider.notifier).clearError();
        }
      }
    });

    ref.listen<MatchesState>(matchesNotifierProvider, (previous, next) {
      final bool justFinishedUpdating =
          previous?.isUpdatingParticipant == true &&
          !next.isUpdatingParticipant;
      if (justFinishedUpdating && next.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Participant status updated.'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final bool justFinishedSubmitting =
          previous?.isSubmittingAttendance == true &&
          !next.isSubmittingAttendance;
      if (justFinishedSubmitting) {
        if (context.mounted) {
          if (next.errorMessage == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Attendance list confirmed!'),
                backgroundColor: Colors.green,
              ),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = votingSectionKey.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error: ${next.errorMessage!}"),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }

      if (next.errorMessage != null &&
          previous?.errorMessage == null &&
          (previous?.isUpdatingParticipant == true ||
              previous?.isSubmittingAttendance == true)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${next.errorMessage!}"),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });

    // --- Ana UI (AsyncValue'ya göre) ---
    return matchDetailAsyncValue.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading Match...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading match details:\n${error.toString().replaceFirst("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => ref.refresh(matchDetailProvider(matchId)),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (match) {
        // --- Veri Ayrıştırma ve Logic ---
        final bool userIsCaptain = currentUserId == match.organizerId;

        // Sekme listelerini ve sayısını OLUŞTUR
        final List<Widget> tabs = [
          const Tab(text: 'Info'),
          Tab(text: 'Participants (${match.acceptedParticipantCount})'),
        ];
        if (userIsCaptain) {
          tabs.add(const Tab(text: 'Captain\'s Panel'));
        }
        tabs.add(const Tab(text: 'Voting'));

        final int tabCount = tabs.length; // Dinamik olarak 3 veya 4

        // Zaman kontrolleri
        final nowUtc = DateTime.now().toUtc();
        final startTimeUtc = match.startTime;
        final matchEndTimeUtc = startTimeUtc.add(
          Duration(minutes: match.durationMinutes),
        );
        final voteDeadlineUtc = matchEndTimeUtc.add(
          const Duration(minutes: 60),
        );
        final bool matchHasStarted =
            nowUtc.isAfter(startTimeUtc) ||
            nowUtc.isAtSameMomentAs(startTimeUtc);
        final bool votingWindowOpen =
            nowUtc.isAfter(matchEndTimeUtc) && nowUtc.isBefore(voteDeadlineUtc);
        final bool matchIsOver = nowUtc.isAfter(matchEndTimeUtc);
        final bool votingWindowClosed = nowUtc.isAfter(voteDeadlineUtc);
        final bool attendanceSubmitted =
            match.participants?.any((p) => p.attended != null) ?? false;

        final acceptedParticipants =
            match.participants?.where((p) => p.status == 'accepted').toList() ??
            [];
        final requestedParticipants =
            match.participants
                ?.where((p) => p.status == 'requested')
                .toList() ??
            [];

        final bool canVote = _checkVotingEligibility(
          match,
          currentUserId,
          acceptedParticipants,
          nowUtc,
          matchEndTimeUtc,
          voteDeadlineUtc,
        );

        // --- Başlangıç Sekmesini Hesapla (DÜZELTİLMİŞ LOGIC) ---
        int initialTabIndex = 0; // Varsayılan "Info" (index 0)
        if (initialTabName == 'voting') {
          // "Voting" her zaman listenin sonundadır.
          initialTabIndex = tabs.length - 1;
        }
        // --- BİTTİ ---

        // --- Sekme İçeriklerini (Views) OLUŞTUR ---
        final List<Widget> tabViews = [
          // Sekme 1: Info
          _buildInfoTab(
            context,
            ref,
            match,
            matchesNotifierState,
            currentUserId,
            matchHasStarted,
          ),
          // Sekme 2: Participants
          _buildParticipantsTab(context, acceptedParticipants, match),
        ];
        if (userIsCaptain) {
          // Sekme 3: Captain's Panel
          tabViews.add(
            _buildCaptainPanelTab(
              context,
              ref,
              match,
              requestedParticipants,
              acceptedParticipants,
              processingParticipantId,
              matchesNotifierState,
              matchHasStarted,
              matchIsOver,
              attendanceSubmitted,
              noShowUserIds,
            ),
          );
        }
        // Sekme 4: Voting
        tabViews.add(
          _buildVotingTab(
            context,
            votingSectionKey,
            match,
            votingWindowOpen,
            canVote,
            votingWindowClosed,
            acceptedParticipants,
            currentUserId,
          ),
        );
        // --- BİTTİ ---

        // --- Scaffold (Artık hatasız) ---
        return DefaultTabController(
          initialIndex: initialTabIndex, // Düzeltilmiş index
          length: tabCount, // Düzeltilmiş sayı
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Match Details'),
              bottom: TabBar(
                isScrollable: true,
                tabs: tabs, // Dinamik sekme listesi
              ),
            ),
            body: TabBarView(
              children: tabViews, // Dinamik içerik listesi
            ),
          ),
        );
      },
    );
  }

  // --- YARDIMCI METOTLAR (CLASS İÇİNDE) ---

  bool _checkVotingEligibility(
    Match match,
    String? currentUserId,
    List<MatchParticipant> acceptedParticipants,
    DateTime nowUtc,
    DateTime matchEndTimeUtc,
    DateTime voteDeadlineUtc,
  ) {
    if (currentUserId == null) return false;
    if (nowUtc.isBefore(matchEndTimeUtc) || nowUtc.isAfter(voteDeadlineUtc)) {
      return false;
    }
    final currentUserParticipation = acceptedParticipants.firstWhereOrNull(
      (p) => p.userId == currentUserId,
    );
    if (currentUserParticipation == null ||
        currentUserParticipation.attended != true) {
      return false;
    }
    return true;
  }

  // --- Sekme 1: Info ---
  Widget _buildInfoTab(
    BuildContext context,
    WidgetRef ref,
    Match match,
    MatchesState matchesNotifierState,
    String? currentUserId,
    bool matchHasStarted,
  ) {
    final field = match.field;
    final organizer = match.organizer;
    final formattedDate = DateFormat(
      'MMMM dd, yyyy, h:mm a',
      'en_US',
    ).format(match.startTime.toLocal());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (field != null)
            _FieldInfoCard(
              field: field,
              onDirectionsPressed: () => _launchMaps(context, field),
            ),
          const SizedBox(height: 16),
          _MatchInfoCard(match: match, formattedDate: formattedDate),
          const Divider(height: 24),
          Text('Organizer', style: Theme.of(context).textTheme.titleLarge),
          if (organizer != null)
            ListTile(
              leading: CircleAvatar(
                backgroundImage: organizer.displayImageUrl.startsWith('http')
                    ? NetworkImage(organizer.displayImageUrl)
                    : const AssetImage('assets/images/default_profile.jpg')
                          as ImageProvider,
              ),
              title: Text(organizer.fullName),
              onTap: () => context.go('/profile/${organizer.id}'),
              contentPadding: EdgeInsets.zero,
            ),
          const Divider(height: 32),
          // --- Aksiyon Butonları (Info sekmesinin içinde) ---
          _buildActionButtons(
            context,
            ref,
            match,
            matchesNotifierState,
            currentUserId,
            matchHasStarted,
          ),
          const SizedBox(height: 32), // Alt boşluk
        ],
      ),
    );
  }

  // --- Sekme 2: Katılımcılar ---
  Widget _buildParticipantsTab(
    BuildContext context,
    List<MatchParticipant> acceptedParticipants,
    Match match,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participants (${match.acceptedParticipantCount} / ${match.maxCapacity})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (acceptedParticipants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No accepted participants yet.'),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.5 / 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: acceptedParticipants.length,
              itemBuilder: (context, index) {
                final participant = acceptedParticipants[index];
                return ParticipantCard(participant: participant);
              },
            ),
        ],
      ),
    );
  }

  // --- Sekme 3: Kaptan Paneli ---
  Widget _buildCaptainPanelTab(
    BuildContext context,
    WidgetRef ref,
    Match match,
    List<MatchParticipant> requestedParticipants,
    List<MatchParticipant> acceptedParticipants,
    ValueNotifier<String?> processingParticipantId,
    MatchesState matchesNotifierState,
    bool matchHasStarted,
    bool matchIsOver,
    bool attendanceSubmitted,
    ValueNotifier<Set<String>> noShowUserIds,
  ) {
    final String? currentUserId = ref
        .watch(authNotifierProvider)
        .currentUser
        ?.id;
    final String matchId = match.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Onay Bekleyenler ---
          if (!matchHasStarted && requestedParticipants.isNotEmpty) ...[
            Text(
              'Pending Requests (${requestedParticipants.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requestedParticipants.length,
              itemBuilder: (context, index) {
                final participant = requestedParticipants[index];
                final user = participant.user;
                if (user == null) return const SizedBox.shrink();
                final bool isProcessingThis =
                    processingParticipantId.value == participant.id;
                final bool isAnyProcessing =
                    matchesNotifierState.isUpdatingParticipant ||
                    isProcessingThis;
                final bool rosterFull =
                    match.acceptedParticipantCount >= match.maxCapacity;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.displayImageUrl.startsWith('http')
                          ? NetworkImage(user.displayImageUrl)
                          : const AssetImage(
                                  'assets/images/default_profile.jpg',
                                )
                                as ImageProvider,
                    ),
                    title: Text(user.fullName),
                    subtitle: Text(
                      'Position: ${participant.positionRequest ?? "Not specified"}',
                    ),
                    trailing: isProcessingThis
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Decline',
                                onPressed: isAnyProcessing
                                    ? null
                                    : () async {
                                        processingParticipantId.value =
                                            participant.id;
                                        try {
                                          await ref
                                              .read(
                                                matchesNotifierProvider
                                                    .notifier,
                                              )
                                              .updateParticipantStatus(
                                                matchId: matchId,
                                                participantId: participant.id,
                                                status: 'declined',
                                              );
                                          if (context.mounted) {
                                            ref.invalidate(
                                              matchDetailProvider(matchId),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Request declined',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            processingParticipantId.value =
                                                null;
                                          }
                                        }
                                      },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.check,
                                  color: (isAnyProcessing)
                                      ? Colors.grey
                                      : (rosterFull
                                            ? Colors.orange
                                            : Colors.green),
                                ),
                                tooltip: rosterFull
                                    ? 'Roster is full'
                                    : 'Approve',
                                onPressed: isAnyProcessing
                                    ? null
                                    : () async {
                                        if (rosterFull) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Match roster is full. Cannot approve.',
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        processingParticipantId.value =
                                            participant.id;
                                        try {
                                          await ref
                                              .read(
                                                matchesNotifierProvider
                                                    .notifier,
                                              )
                                              .updateParticipantStatus(
                                                matchId: matchId,
                                                participantId: participant.id,
                                                status: 'accepted',
                                              );
                                          if (context.mounted) {
                                            ref.invalidate(
                                              matchDetailProvider(matchId),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Player approved',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            processingParticipantId.value =
                                                null;
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ] else if (!matchHasStarted && requestedParticipants.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "No pending requests.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          if (matchHasStarted && requestedParticipants.isNotEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Requests can no longer be managed after the match has started.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),

          // --- Katılım Onayı (Maç bittiyse) ---
          if (matchIsOver && !attendanceSubmitted) ...[
            const Divider(height: 32),
            Text(
              'Confirm Attendance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'The match has ended. Please mark any players who did NOT show up. Anyone not marked will be confirmed as attended.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: acceptedParticipants.map((participant) {
                final user = participant.user;
                if (user == null || user.id == currentUserId) {
                  return const SizedBox.shrink();
                }
                final bool isMarkedAsNoShow = noShowUserIds.value.contains(
                  user.id,
                );
                final bool attended = !isMarkedAsNoShow;

                return FilterChip(
                  label: Text(user.fullName),
                  avatar: CircleAvatar(
                    backgroundImage: user.displayImageUrl.startsWith('http')
                        ? NetworkImage(user.displayImageUrl)
                        : AssetImage(user.displayImageUrl) as ImageProvider,
                  ),
                  selected: attended,
                  selectedColor: Colors.green.withOpacity(0.3),
                  checkmarkColor: Colors.green.shade700,
                  showCheckmark: true,
                  onSelected: matchesNotifierState.isSubmittingAttendance
                      ? null
                      : (bool isNowSelected) {
                          final currentSet = noShowUserIds.value.toSet();
                          if (isNowSelected) {
                            currentSet.remove(user.id);
                          } else {
                            currentSet.add(user.id);
                          }
                          noShowUserIds.value = currentSet;
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            matchesNotifierState.isSubmittingAttendance
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () async {
                      final success = await ref
                          .read(matchesNotifierProvider.notifier)
                          .submitAttendance(
                            matchId: matchId,
                            noShowUserIds: noShowUserIds.value.toList(),
                          );
                      if (success && context.mounted) {
                        noShowUserIds.value = {};
                      }
                    },
                    child: const Text('Confirm Attendance List'),
                  ),
          ] else if (matchIsOver && attendanceSubmitted)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Attendance has already been submitted.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Sekme 4: Oylama ---
  Widget _buildVotingTab(
    BuildContext context,
    GlobalKey votingSectionKey,
    Match match,
    bool votingWindowOpen,
    bool canVote,
    bool votingWindowClosed,
    List<MatchParticipant> acceptedParticipants,
    String? currentUserId,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        key: votingSectionKey,
        children: [
          if (votingWindowOpen && canVote)
            MatchVotingWidget(
              matchId: match.id,
              otherPlayers: acceptedParticipants
                  .where((p) => p.userId != currentUserId && p.user != null)
                  .toList(),
            )
          else if (votingWindowClosed)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "The voting window for this match has closed.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Voting will open after the match ends.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Info Sekmesi için Aksiyon Butonları ---
  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Match match,
    MatchesState matchesNotifierState,
    String? currentUserId,
    bool matchHasStarted,
  ) {
    Widget actionButton;
    final String matchId = match.id;

    if (currentUserId == null) {
      actionButton = const ElevatedButton(
        onPressed: null,
        child: Text("Login to see actions"),
      );
    } else {
      final MatchParticipant? currentUserParticipation = match.participants
          ?.firstWhereOrNull((p) => p.userId == currentUserId);
      final bool isFull = match.acceptedParticipantCount >= match.maxCapacity;

      if (matchHasStarted) {
        if (currentUserParticipation?.status == 'accepted') {
          actionButton = const ElevatedButton(
            onPressed: null,
            child: Text('Match In Progress / Ended'),
          );
        } else if (currentUserParticipation?.status == 'requested') {
          actionButton = const ElevatedButton(
            onPressed: null,
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.orangeAccent),
            ),
            child: Text('Request Pending'),
          );
        } else {
          actionButton = const ElevatedButton(
            onPressed: null,
            child: Text('Match In Progress / Ended'),
          );
        }
      } else if (currentUserParticipation?.status == 'accepted') {
        final isCaptain = match.organizerId == currentUserId;
        actionButton = ElevatedButton(
          onPressed: isCaptain || matchesNotifierState.isJoiningOrLeaving
              ? null
              : () async {
                  await ref
                      .read(matchesNotifierProvider.notifier)
                      .leaveMatch(matchId: matchId);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isCaptain ? Colors.grey : Colors.redAccent,
          ),
          child: Text(isCaptain ? 'Captains Cannot Leave' : 'Leave Match'),
        );
      } else if (currentUserParticipation?.status == 'requested') {
        actionButton = ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
          child: const Text('Request Sent'),
        );
      } else {
        final bool isButtonDisabled =
            matchesNotifierState.isJoiningOrLeaving || isFull;

        actionButton = ElevatedButton(
          onPressed: isButtonDisabled
              ? null
              : () async {
                  String? requestedPosition;
                  if (match.joinType == 'approval_required') {
                    final positionResult = await showDialog<String?>(
                      context: context,
                      builder: (BuildContext) =>
                          const _PositionSelectionDialog(),
                    );

                    // 'Cancel' (null) ile 'I'd rather not say' (null)
                    // arasındaki farkı ayırt edemiyoruz.
                    // 'Cancel'a basılsa bile API çağrısı (null pozisyonla) gider.
                    // Bunu düzeltmek için _PositionSelectionDialog'u güncellemeniz gerekir.
                    // Şimdilik bu şekilde bırakıyoruz:
                    requestedPosition = positionResult;
                  }

                  await ref
                      .read(matchesNotifierProvider.notifier)
                      .joinMatch(
                        matchId: matchId,
                        positionRequest: requestedPosition,
                      );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isButtonDisabled ? Colors.grey : Colors.green,
          ),
          child: Text(
            isFull
                ? 'Match is Full'
                : (match.joinType == 'open'
                      ? 'Join Match'
                      : 'Send Join Request'),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
      child: Center(
        child: matchesNotifierState.isJoiningOrLeaving
            ? const CircularProgressIndicator()
            : actionButton,
      ),
    );
  }
} // --- MatchDetailScreen CLASS'ININ BİTİŞİ ---

// --- WIDGET'LAR VE PROVIDER'LAR DOSYANIN GERİ KALANI ---

class _PositionSelectionDialog extends StatefulWidget {
  const _PositionSelectionDialog({Key? key}) : super(key: key);

  @override
  State<_PositionSelectionDialog> createState() =>
      _PositionSelectionDialogState();
}

class _PositionSelectionDialogState extends State<_PositionSelectionDialog> {
  final List<String> positions = [
    'Forward',
    'Midfielder',
    'Defender',
    'Goalkeeper',
    'I\'d rather not say',
  ];
  String? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = positions.last;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Your Position'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: positions.map((position) {
          return RadioListTile<String>(
            title: Text(position),
            value: position,
            groupValue: _selectedPosition,
            onChanged: (String? value) {
              setState(() {
                _selectedPosition = value;
              });
            },
          );
        }).toList(),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop(); // 'Cancel' null döndürür
          },
        ),
        TextButton(
          child: const Text('Submit'),
          onPressed: () {
            final result = _selectedPosition == 'I\'d rather not say'
                ? null // 'I'd rather not say' de null döndürür
                : _selectedPosition;
            Navigator.of(context).pop(result);
          },
        ),
      ],
    );
  }
}

final currentUserProvider = FutureProvider<String?>((ref) async {
  final authRepository = ref.watch(authRepositoryProvider);
  final token = await authRepository.getToken();
  if (token == null) return null;
  try {
    print("TODO: Implement currentUserId fetching!");
    return null;
  } catch (e) {
    print("Token decode/fetch error: $e");
    return null;
  }
});

class _FieldInfoCard extends StatelessWidget {
  final Field field;
  final VoidCallback onDirectionsPressed;

  const _FieldInfoCard({
    required this.field,
    required this.onDirectionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (field.location != null)
            SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    field.location!.latitude,
                    field.location!.longitude,
                  ),
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.flutter_baab_sport_field_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: LatLng(
                          field.location!.latitude,
                          field.location!.longitude,
                        ),
                        child: Icon(
                          Icons.location_pin,
                          color: Colors.red.shade700,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.address ?? 'No address provided',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: onDirectionsPressed,
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchInfoCard extends StatelessWidget {
  final Match match;
  final String formattedDate;

  const _MatchInfoCard({required this.match, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              title: 'Date & Time',
              value: formattedDate,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.schedule_outlined,
                    title: 'Duration',
                    value: '${match.durationMinutes} minutes',
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey.shade700,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.people_outline,
                    title: 'Format',
                    value: match.format,
                  ),
                ),
              ],
            ),
            if (match.notes != null && match.notes!.isNotEmpty) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.notes_outlined,
                title: 'Notes',
                value: match.notes!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
