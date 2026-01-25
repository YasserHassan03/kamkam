import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/match.dart';
import '../../../data/models/standing.dart';
import '../../../data/models/team.dart';
import '../../../data/models/tournament.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/team_providers.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/standing_providers.dart';
import '../../../providers/user_profile_providers.dart';
import '../../widgets/bracket/bracket.dart';
import '../../widgets/common/loading_error_widgets.dart';
import '../../widgets/match/match_card.dart';
import '../../widgets/standings/standings_table.dart';

/// Overview tab for league tournaments: quick stats + recent activity
class _OverviewTab extends ConsumerWidget {
  final Tournament tournament;
  final AsyncValue<List<Team>> teamsAsync;
  final AsyncValue<List<Match>> matchesAsync;

  const _OverviewTab({
    required this.tournament,
    required this.teamsAsync,
    required this.matchesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = teamsAsync.when(
      data: (data) => data,
      loading: () => const <Team>[],
      error: (_, __) => const <Team>[],
    );
    final matches = matchesAsync.when(
      data: (data) => data,
      loading: () => const <Match>[],
      error: (_, __) => const <Match>[],
    );
    final playedMatches = matches.where((m) => m.hasResult).length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teamsByTournamentProvider(tournament.id));
        ref.invalidate(matchesByTournamentProvider(tournament.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Centered stat cards
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatCard(
                label: 'Teams',
                value: teams.length.toString(),
                icon: Icons.groups_rounded,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Matches',
                value: matches.length.toString(),
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Played',
                value: playedMatches.toString(),
                icon: Icons.sports_soccer_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Tournament Status Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tournament Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TournamentStatus>(
                    value: tournament.status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: TournamentStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      );
                    }).toList(),
                    onChanged: (newStatus) async {
                      if (newStatus == null || newStatus == tournament.status) {
                        return;
                      }
                      
                      try {
                        final updated = tournament.copyWith(
                          status: newStatus,
                          updatedAt: DateTime.now(),
                        );
                        await ref.read(updateTournamentProvider(updated).future);
                        
                      } catch (e) {
                        // Error handled silently
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          FilledButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => _GenerateFixturesDialog(
                  tournamentId: tournament.id,
                  ref: ref,
                ),
              );
            },
            icon: const Icon(Icons.auto_mode_rounded),
            label: const Text('Generate Fixtures'),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Matches',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (matches.isEmpty)
            const EmptyStateWidget(
              icon: Icons.sports_soccer,
              title: 'No Matches Yet',
              subtitle: 'Generate fixtures or add matches manually.',
            )
          else
            ...matches
                .take(5)
                .map(
                  (m) => MatchCard(
                    match: m,
                    onTap: () => context.push(
                      '/admin/tournaments/${tournament.id}/matches/${m.id}/result',
                    ),
                  ),
                )
                .toList(),
        ],
      ),
    );
  }
}

/// Simple stat card widget
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Standings tab for knockout / group phase - shows bracket (draw) instead of standings
class _BracketStandingsTab extends ConsumerWidget {
  final String tournamentId;
  final Tournament tournament;
  const _BracketStandingsTab({
    required this.tournamentId,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For group_knockout format, show sub-tabs for Groups and Knockouts
    if (tournament.format == 'group_knockout') {
      return DefaultTabController(
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
                  _GroupsTab(tournamentId: tournamentId),
                  _KnockoutsTab(tournamentId: tournamentId),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // For knockout format, just show the bracket
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
                title: 'No Bracket Yet',
                subtitle: 'Generate fixtures to create the knockout bracket.',
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Bracket(
              rounds: rounds,
              tournamentId: tournamentId,
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

/// Groups tab for group_knockout tournaments - shows standings for each group
class _GroupsTab extends ConsumerWidget {
  final String tournamentId;
  const _GroupsTab({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsByTournamentProvider(tournamentId));
    final tournamentAsync = ref.watch(tournamentByIdProvider(tournamentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(standingsByTournamentProvider(tournamentId));
        ref.invalidate(tournamentByIdProvider(tournamentId));
      },
      child: tournamentAsync.when(
        data: (tournament) {
          final qualifiersPerGroup = tournament?.qualifiersPerGroup;
          
          return standingsAsync.when(
            data: (allStandings) {
          // Group standings by group_id
          final standingsByGroup = <String?, List<Standing>>{};
          
          for (final standing in allStandings) {
            final groupId = standing.groupId;
            standingsByGroup.putIfAbsent(groupId, () => []).add(standing);
          }

          // Filter out null group_id (those are for league format, not group stage)
          final groupStandings = standingsByGroup.entries
              .where((entry) => entry.key != null)
              .toList();

          if (groupStandings.isEmpty) {
            return const Center(
              child: EmptyStateWidget(
                icon: Icons.groups_rounded,
                title: 'No Group Standings Yet',
                subtitle: 'Generate fixtures to create group stage matches.',
              ),
            );
          }

          // Sort groups by group_id (or by first team's group number if available)
          groupStandings.sort((a, b) {
            // Sort by group_id as string for consistent ordering
            return (a.key ?? '').compareTo(b.key ?? '');
          });
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupStandings.length,
            itemBuilder: (context, index) {
              final groupEntry = groupStandings[index];
              final groupStandingsList = groupEntry.value;
              
              // Sort standings by points, GD, GF
              groupStandingsList.sort((a, b) {
                final pointsDiff = b.points.compareTo(a.points);
                if (pointsDiff != 0) return pointsDiff;
                final gdDiff = b.goalDifference.compareTo(a.goalDifference);
                if (gdDiff != 0) return gdDiff;
                return b.goalsFor.compareTo(a.goalsFor);
              });

              // Assign positions within the group (1, 2, 3, ...) based on sorted order
              // This overrides the global position from the database
              for (int i = 0; i < groupStandingsList.length; i++) {
                groupStandingsList[i] = groupStandingsList[i].copyWith(
                  position: i + 1,
                );
              }

              // Get group name - use groupNumber to convert to letter (Group A, B, C, etc.)
              String groupName;
              if (groupStandingsList.isNotEmpty && groupStandingsList.first.team != null) {
                final firstTeam = groupStandingsList.first.team!;
                final groupNumber = firstTeam.groupNumber;
                if (groupNumber != null && groupNumber > 0 && groupNumber < 27) {
                  groupName = 'Group ${String.fromCharCode(64 + groupNumber)}';
                } else {
                  // Fallback: try to infer from group_id or use index
                  groupName = 'Group ${String.fromCharCode(65 + index)}'; // A=65, B=66, etc.
                }
              } else {
                // Use index to generate letter (A=0, B=1, etc.)
                groupName = 'Group ${String.fromCharCode(65 + index)}';
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
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(tournamentByIdProvider(tournamentId)),
        ),
      ),
    );
  }
}

/// Knockouts tab for group_knockout tournaments - shows the knockout bracket
class _KnockoutsTab extends ConsumerStatefulWidget {
  final String tournamentId;
  const _KnockoutsTab({required this.tournamentId});

  @override
  ConsumerState<_KnockoutsTab> createState() => _KnockoutsTabState();
}

class _KnockoutsTabState extends ConsumerState<_KnockoutsTab> {
  bool _attemptedAutoGenerate = false;
  bool _isGenerating = false;

  Future<void> _generateKnockouts() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final result = await ref
          .read(generateGroupKnockoutKnockoutsProvider(widget.tournamentId).future);

      if (!mounted) return;

      if (!result.success) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Could not generate knockouts'),
            content: Text(result.error ?? 'Unknown error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Refresh bracket/matches
        ref.invalidate(matchesByTournamentProvider(widget.tournamentId));
        ref.invalidate(bracketByTournamentProvider(widget.tournamentId));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bracketAsync = ref.watch(bracketByTournamentProvider(widget.tournamentId));
    final matchesAsync = ref.watch(matchesByTournamentProvider(widget.tournamentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(matchesByTournamentProvider(widget.tournamentId));
        ref.invalidate(bracketByTournamentProvider(widget.tournamentId));
      },
      child: bracketAsync.when(
        data: (rounds) {
          if (rounds.isEmpty) {
            final matches = matchesAsync.asData?.value;
            final groupMatches = matches?.where((m) => m.roundNumber == null).toList() ?? const <Match>[];
            final groupFinished =
                groupMatches.isNotEmpty && groupMatches.every((m) => m.status == MatchStatus.finished);

            // If group stage is finished and no knockouts exist yet, try to generate once automatically.
            if (groupFinished && !_attemptedAutoGenerate) {
              _attemptedAutoGenerate = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _generateKnockouts();
              });
            }

            if (_isGenerating) {
              return const LoadingWidget(message: 'Generating knockout bracket...');
            }

            return Center(
              child: EmptyStateWidget(
                icon: Icons.account_tree_rounded,
                title: 'No Knockout Bracket Yet',
                subtitle: groupFinished
                    ? 'Group stage is finished. Generate the knockout bracket now.'
                    : 'Knockout bracket will appear after group stage qualifiers are determined.',
                action: groupFinished
                    ? FilledButton.icon(
                        onPressed: _generateKnockouts,
                        icon: const Icon(Icons.auto_mode_rounded),
                        label: const Text('Generate Knockouts'),
                      )
                    : null,
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Bracket(
              rounds: rounds,
              tournamentId: widget.tournamentId,
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(bracketByTournamentProvider(widget.tournamentId)),
        ),
      ),
    );
  }
}

/// Teams management tab
class _TeamsTab extends ConsumerWidget {
  final String tournamentId;
  final AsyncValue<List<Team>> teamsAsync;

  const _TeamsTab({
    required this.tournamentId,
    required this.teamsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: () => context.go(
                  '/admin/tournaments/$tournamentId/teams/new',
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Team'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(teamsByTournamentProvider(tournamentId));
            },
            child: teamsAsync.when(
              data: (teams) {
                if (teams.isEmpty) {
                  return const Center(
                    child: EmptyStateWidget(
                      icon: Icons.groups_rounded,
                      title: 'No Teams Yet',
                      subtitle: 'Add teams to this tournament to get started.',
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: teams.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return ListTile(
                      title: Text(team.name),
                      subtitle: team.shortName != null
                          ? Text(team.shortName!)
                          : null,
                      leading: const Icon(Icons.shield_rounded),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.group_rounded),
                            tooltip: 'Players',
                            onPressed: () => context.go(
                              '/admin/tournaments/$tournamentId/teams/${team.id}/players',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            tooltip: 'Edit team',
                            onPressed: () => context.go(
                              '/admin/tournaments/$tournamentId/teams/${team.id}',
                            ),
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
                onRetry: () => ref.invalidate(teamsByTournamentProvider(tournamentId)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fixtures management tab
class _FixturesTab extends ConsumerWidget {
  final String tournamentId;
  final AsyncValue<List<Match>> matchesAsync;

  const _FixturesTab({
    required this.tournamentId,
    required this.matchesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => _GenerateFixturesDialog(
                        tournamentId: tournamentId,
                        ref: ref,
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_mode_rounded),
                  label: const Text('Generate Fixtures'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go(
                    '/admin/tournaments/$tournamentId/fixtures/new',
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Match'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete all fixtures',
                  icon: const Icon(Icons.delete_forever_rounded),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete all fixtures?'),
                        content: const Text(
                          'This will permanently remove all matches for this tournament.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(deleteAllFixturesProvider(tournamentId).future);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(matchesByTournamentProvider(tournamentId));
            },
            child: matchesAsync.when(
              data: (matches) {
                if (matches.isEmpty) {
                  return const Center(
                    child: EmptyStateWidget(
                      icon: Icons.calendar_today_rounded,
                      title: 'No Fixtures',
                      subtitle: 'Generate fixtures or add matches manually.',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return MatchCard(
                      match: match,
                      showDate: true,
                      onTap: () => context.push(
                        '/admin/tournaments/$tournamentId/matches/${match.id}/result',
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(matchesByTournamentProvider(tournamentId)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Remove duplicate placeholder _StandingsTab class
/// Admin view for managing a specific tournament
class TournamentAdminScreen extends ConsumerWidget {
  final String tournamentId;

  const TournamentAdminScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(tournamentId));
    final teamsAsync = ref.watch(teamsByTournamentProvider(tournamentId));
    final matchesAsync = ref.watch(matchesByTournamentProvider(tournamentId));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament')),
            body: const Center(child: Text('Tournament not found')),
          );
        }
        
        // Validate tournament has required fields before rendering
        try {
          // Access all required fields to trigger any type errors early
          final _ = tournament.id;
          final _name = tournament.name;
          final _format = tournament.format;
          final _status = tournament.status;
          // Use variables to avoid unused variable warnings
          if (_name.isEmpty || _format.isEmpty || _status.name.isEmpty) {
            // This will never execute, just using the variables
          }
        } catch (e, stackTrace) {
          debugPrint('ERROR: Tournament object has invalid fields');
          debugPrint('Error: $e');
          debugPrint('Stack trace: $stackTrace');
          debugPrint('Tournament data: id=${tournament.id}, name=${tournament.name}, format=${tournament.format}');
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: AppErrorWidget(
              message: 'Invalid tournament data: $e',
              onRetry: () => ref.invalidate(tournamentByIdProvider(tournamentId)),
            ),
          );
        }
        
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tournament.name),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/admin');
                  }
                },
              ),
              actions: [
                // Admin-only: Hide/Show tournament toggle
                Consumer(
                  builder: (context, ref, _) {
                    final isAdmin = ref.watch(isUserAdminProvider);
                    if (!isAdmin) return const SizedBox.shrink();
                    
                    return IconButton(
                      icon: Icon(tournament.hiddenByAdmin ? Icons.visibility_off : Icons.visibility),
                      tooltip: tournament.hiddenByAdmin 
                          ? 'Show Tournament (Currently Hidden)' 
                          : 'Hide Tournament from Public',
                      onPressed: () => _showToggleVisibilityDialog(
                        context, 
                        ref, 
                        tournament.id, 
                        tournament.name,
                        tournament.hiddenByAdmin,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Tournament',
                  onPressed: () => _showDeleteTournamentDialog(context, ref, tournament.id, tournament.name),
                ),
              ],
              bottom: TabBar(
                tabs: [
                  const Tab(text: 'Overview'),
                  const Tab(text: 'Teams'),
                  const Tab(text: 'Fixtures'),
                  Tab(text: tournament.format == 'league' ? 'Standings' : 'Draw'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OverviewTab(
                  tournament: tournament,
                  teamsAsync: teamsAsync,
                  matchesAsync: matchesAsync,
                ),
                _TeamsTab(
                  tournamentId: tournamentId,
                  teamsAsync: teamsAsync,
                ),
                _FixturesTab(
                  tournamentId: tournamentId,
                  matchesAsync: matchesAsync,
                ),
                tournament.format == 'league'
                  ? _StandingsTab(tournamentId: tournamentId)
                  : _BracketStandingsTab(
                      tournamentId: tournamentId,
                      tournament: tournament,
                    ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const LoadingWidget(),
      ),
      error: (e, stackTrace) {
        // Log the error with full details
        debugPrint('ERROR: TournamentAdminScreen - Failed to load tournament $tournamentId');
        debugPrint('Error: $e');
        debugPrint('Stack trace: $stackTrace');
        if (e is TypeError) {
          debugPrint('TypeError details: ${e.toString()}');
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(tournamentByIdProvider(tournamentId)),
          ),
        );
      },
    );
  }
}

class _GenerateFixturesDialog extends StatefulWidget {
  final String tournamentId;
  final WidgetRef ref;
  const _GenerateFixturesDialog({required this.tournamentId, required this.ref});

  @override
  State<_GenerateFixturesDialog> createState() => _GenerateFixturesDialogState();
}

class _GenerateFixturesDialogState extends State<_GenerateFixturesDialog> {
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    // Ensure loading state is cleared when dialog is disposed
    _isLoading = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Fixtures'),
      content: _isLoading
          ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This will generate fixtures based on the tournament format (league, knockout, or group + knockout). Existing fixtures may be affected.'),
                const SizedBox(height: 8),
                Text(
                  'Note: This may take up to 2 minutes for large tournaments.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ]
              ],
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  try {
                    final request = GenerateFixturesRequest(tournamentId: widget.tournamentId);
                    // Increased timeout for large tournaments - fixture generation can take time
                    final result = await widget.ref
                        .read(generateFixturesProvider(request).future)
                        .timeout(const Duration(seconds: 120)); // 2 minutes
                    
                    if (!mounted) return;
                    
                    // Clear loading state BEFORE popping dialog
                    setState(() {
                      _isLoading = false;
                    });
                    
                    if (result.success) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        _error = result.error ?? 'Failed to generate fixtures.';
                      });
                    }
                  } on TimeoutException {
                    if (!mounted) return;
                    setState(() {
                      _isLoading = false;
                      _error = 'Fixture generation timed out after 2 minutes. This can happen with large tournaments or if the database is under heavy load. Please try again, or check your database logs for errors.';
                    });
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _isLoading = false;
                      _error = e.toString();
                    });
                  }
                },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

// Toggle tournament visibility dialog (admin only)
void _showToggleVisibilityDialog(
  BuildContext context,
  WidgetRef ref,
  String tournamentId,
  String tournamentName,
  bool currentlyHidden,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(currentlyHidden ? 'Show Tournament' : 'Hide Tournament'),
      content: Text(
        currentlyHidden
            ? 'Are you sure you want to show "$tournamentName" to the public?\n\n'
                'This will make the tournament visible to all users, overriding the organiser\'s visibility settings.'
            : 'Are you sure you want to hide "$tournamentName" from the public?\n\n'
                'This will hide the tournament from public view, even if the organiser has set it to public. '
                'The tournament will still be visible to admins and the organiser.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              await ref.read(toggleTournamentVisibilityProvider((
                tournamentId: tournamentId,
                hidden: !currentlyHidden,
              )).future);
              
            } catch (e) {
              // Error handled silently
            }
          },
          child: Text(currentlyHidden ? 'Show Tournament' : 'Hide Tournament'),
        ),
      ],
    ),
  );
}

// Delete tournament dialog
void _showDeleteTournamentDialog(BuildContext context, WidgetRef ref, String tournamentId, String tournamentName) {
  // Store the outer context for navigation
  final navigatorContext = context;
  
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Tournament'),
      content: Text(
        'Are you sure you want to delete "$tournamentName"?\n\n'
        'This will permanently delete:\n'
        '• All teams and players\n'
        '• All matches and fixtures\n'
        '• All standings\n'
        '• The tournament itself\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              // Navigate immediately to prevent showing "Tournament not found"
              navigatorContext.go('/admin');
              
              // Then delete the tournament
              await ref.read(deleteTournamentProvider(tournamentId).future);
            } catch (e) {
              // Error handled silently
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// Top-level _StandingsTab class
class _StandingsTab extends ConsumerWidget {
  final String tournamentId;

  const _StandingsTab({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsByTournamentProvider(tournamentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(standingsByTournamentProvider(tournamentId));
      },
      child: standingsAsync.when(
        data: (standings) {
          if (standings.isEmpty) {
            return const Center(
              child: EmptyStateWidget(
                icon: Icons.leaderboard,
                title: 'No Standings',
                subtitle: 'Standings will appear after matches are played',
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: StandingsTable(standings: standings),
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
