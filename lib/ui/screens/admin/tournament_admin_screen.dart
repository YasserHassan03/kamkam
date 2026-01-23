import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import '../../../core/constants/enums.dart';
import '../../../data/models/match.dart';
import '../../../data/models/team.dart';
import '../../../data/models/tournament.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/team_providers.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/standing_providers.dart';
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
    final teams = teamsAsync.valueOrNull ?? const <Team>[];
    final matches = matchesAsync.valueOrNull ?? const <Match>[];
    final playedMatches = matches.where((m) => m.hasResult).length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teamsByTournamentProvider(tournament.id));
        ref.invalidate(matchesByTournamentProvider(tournament.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                label: 'Teams',
                value: teams.length.toString(),
                icon: Icons.groups_rounded,
              ),
              _StatCard(
                label: 'Matches',
                value: matches.length.toString(),
                icon: Icons.calendar_month_rounded,
              ),
              _StatCard(
                label: 'Played',
                value: playedMatches.toString(),
                icon: Icons.sports_soccer_rounded,
              ),
            ],
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

/// Bracket overview for knockout / group + knockout tournaments
class _BracketOverviewTab extends ConsumerWidget {
  final String tournamentId;
  const _BracketOverviewTab({required this.tournamentId});

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

/// Standings tab for knockout / group phase (reuses league standings table)
class _BracketStandingsTab extends ConsumerWidget {
  final String tournamentId;
  const _BracketStandingsTab({required this.tournamentId});

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
                title: 'No Group Standings',
                subtitle: 'Standings will appear after group matches are played.',
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
              const Spacer(),
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
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tournament.name),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin'),
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Teams'),
                  Tab(text: 'Fixtures'),
                  Tab(text: 'Standings'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                tournament.format == 'league'
                  ? _OverviewTab(
                      tournament: tournament,
                      teamsAsync: teamsAsync,
                      matchesAsync: matchesAsync,
                    )
                  : _BracketOverviewTab(tournamentId: tournamentId),
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
                  : _BracketStandingsTab(tournamentId: tournamentId),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const LoadingWidget(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(tournamentByIdProvider(tournamentId)),
        ),
      ),
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Fixtures'),
      content: _isLoading
          ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This will generate fixtures based on the tournament format (league, knockout, or group + knockout). Existing fixtures may be affected.'),
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
                    final result = await widget.ref.read(generateFixturesProvider(request).future);
                    if (mounted) {
                      if (result.success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Generated ${result.matchesCreated} fixtures')),
                        );
                      } else {
                        setState(() {
                          _error = result.error ?? 'Failed to generate fixtures.';
                          _isLoading = false;
                        });
                      }
                    }
                  } catch (e) {
                    setState(() {
                      _error = e.toString();
                      _isLoading = false;
                    });
                  }
                },
          child: const Text('Generate'),
        ),
      ],
    );
  }
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
