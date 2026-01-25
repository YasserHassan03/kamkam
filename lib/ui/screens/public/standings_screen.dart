import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/standing_providers.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/match_providers.dart';
import '../../../data/models/standing.dart';
import '../../widgets/common/loading_error_widgets.dart';
import '../../widgets/standings/standings_table.dart';
import '../../widgets/bracket/bracket.dart';

/// Full league standings screen or bracket for knockout tournaments
class StandingsScreen extends ConsumerWidget {
  final String tournamentId;

  const StandingsScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(tournamentId));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament')),
            body: const AppErrorWidget(message: 'Tournament not found'),
          );
        }

        // For knockout tournaments, show bracket/draw
        if (tournament.format == 'knockout') {
          return Scaffold(
            appBar: AppBar(
              title: Text(tournament.name),
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(bracketByTournamentProvider(tournamentId));
              },
              child: Consumer(
                builder: (context, ref, _) {
                  final bracketAsync = ref.watch(bracketByTournamentProvider(tournamentId));
                  return bracketAsync.when(
                    data: (rounds) {
                      if (rounds.isEmpty) {
                        final title =
                            tournament.format == 'group_knockout' ? 'No Draw Yet' : 'No Bracket Yet';
                        final subtitle = tournament.format == 'group_knockout'
                            ? 'Draw will appear after the group stage is completed.'
                            : 'Generate fixtures to create the knockout bracket.';

                        return EmptyStateWidget(
                          icon: Icons.account_tree_rounded,
                          title: title,
                          subtitle: subtitle,
                        );
                      }

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Bracket(
                            rounds: rounds,
                            tournamentId: tournamentId,
                          ),
                        ),
                      );
                    },
                    loading: () => const LoadingWidget(),
                    error: (e, _) => AppErrorWidget(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(bracketByTournamentProvider(tournamentId)),
                    ),
                  );
                },
              ),
            ),
          );
        }

        // For group_knockout tournaments, show sub-tabs for Groups and Knockouts (same as admin view)
        if (tournament.format == 'group_knockout') {
          return Scaffold(
            appBar: AppBar(
              title: Text(tournament.name),
            ),
            body: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Groups'),
                      Tab(text: 'Knockouts'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _PublicGroupsTab(
                          tournamentId: tournamentId,
                          qualifiersPerGroup: tournament.qualifiersPerGroup,
                        ),
                        _PublicKnockoutsTab(tournamentId: tournamentId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // For league format, show standings
        return Scaffold(
          appBar: AppBar(
            title: Text(tournament.name),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(standingsByTournamentProvider(tournamentId));
            },
            child: Consumer(
              builder: (context, ref, _) {
                final standingsAsync = ref.watch(standingsByTournamentProvider(tournamentId));
                return standingsAsync.when(
                  data: (standings) {
                    if (standings.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.leaderboard,
                        title: 'No Standings Yet',
                        subtitle: 'Standings will appear once matches are played',
                      );
                    }

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: StandingsTable(
                          standings: standings,
                          showFullStats: true,
                        ),
                      ),
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (e, _) => AppErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(standingsByTournamentProvider(tournamentId)),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const LoadingWidget(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(tournamentByIdProvider(tournamentId)),
        ),
      ),
    );
  }
}

class _PublicGroupsTab extends ConsumerWidget {
  final String tournamentId;
  final int? qualifiersPerGroup;

  const _PublicGroupsTab({
    required this.tournamentId,
    required this.qualifiersPerGroup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsByTournamentProvider(tournamentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(standingsByTournamentProvider(tournamentId));
      },
      child: standingsAsync.when(
        data: (allStandings) {
          // Group standings by group_id
          final standingsByGroup = <String?, List<Standing>>{};
          for (final standing in allStandings) {
            final groupId = standing.groupId;
            standingsByGroup.putIfAbsent(groupId, () => []).add(standing);
          }

          // Filter out null group_id
          final groupStandings = standingsByGroup.entries.where((e) => e.key != null).toList();
          if (groupStandings.isEmpty) {
            return const Center(
              child: EmptyStateWidget(
                icon: Icons.groups_rounded,
                title: 'No Group Standings Yet',
                subtitle: 'Standings will appear once group matches are played.',
              ),
            );
          }

          // Sort groups consistently
          groupStandings.sort((a, b) => (a.key ?? '').compareTo(b.key ?? ''));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupStandings.length,
            itemBuilder: (context, index) {
              final groupEntry = groupStandings[index];
              final groupStandingsList = groupEntry.value;

              // Sort standings within group by points, GD, GF
              groupStandingsList.sort((a, b) {
                final pointsDiff = b.points.compareTo(a.points);
                if (pointsDiff != 0) return pointsDiff;
                final gdDiff = b.goalDifference.compareTo(a.goalDifference);
                if (gdDiff != 0) return gdDiff;
                return b.goalsFor.compareTo(a.goalsFor);
              });

              // Assign positions within group (1..N)
              for (int i = 0; i < groupStandingsList.length; i++) {
                groupStandingsList[i] = groupStandingsList[i].copyWith(position: i + 1);
              }

              // Prefer team.groupNumber if present, otherwise index -> A/B/...
              final inferredLetter = String.fromCharCode(65 + index); // A=65
              String groupName = 'Group $inferredLetter';
              if (groupStandingsList.isNotEmpty && groupStandingsList.first.team?.groupNumber != null) {
                final gn = groupStandingsList.first.team!.groupNumber!;
                if (gn > 0 && gn < 27) {
                  groupName = 'Group ${String.fromCharCode(64 + gn)}';
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        groupName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    StandingsTable(
                      standings: groupStandingsList,
                      qualifiersPerGroup: qualifiersPerGroup,
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(standingsByTournamentProvider(tournamentId)),
        ),
      ),
    );
  }
}

class _PublicKnockoutsTab extends ConsumerWidget {
  final String tournamentId;
  const _PublicKnockoutsTab({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bracketAsync = ref.watch(bracketByTournamentProvider(tournamentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(matchesByTournamentProvider(tournamentId));
        ref.invalidate(bracketByTournamentProvider(tournamentId));
      },
      child: bracketAsync.when(
        data: (rounds) {
          if (rounds.isEmpty) {
            return const Center(
              child: EmptyStateWidget(
                icon: Icons.account_tree_rounded,
                title: 'No Knockout Bracket Yet',
                subtitle: 'Knockout bracket will appear after group stage qualifiers are determined.',
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Bracket(
                rounds: rounds,
                tournamentId: tournamentId,
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(bracketByTournamentProvider(tournamentId)),
        ),
      ),
    );
  }
}
