import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/match.dart';
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
                    
                    if (mounted) {
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
                    }
                  } on TimeoutException {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _error = 'Fixture generation timed out after 2 minutes. This can happen with large tournaments or if the database is under heavy load. Please try again, or check your database logs for errors.';
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _error = e.toString();
                      });
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate'),
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
