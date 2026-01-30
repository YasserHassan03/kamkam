import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/standing_providers.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../core/constants/enums.dart';
import '../../widgets/common/loading_error_widgets.dart';
import '../../widgets/standings/standings_table.dart';
import '../../widgets/match/match_card.dart';

/// Tournament detail screen showing overview with standings, fixtures, and results
class TournamentDetailScreen extends ConsumerWidget {
  final String tournamentId;

  const TournamentDetailScreen({
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

        return Scaffold(
          appBar: AppBar(
            title: Text(tournament.name),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tournamentByIdProvider(tournamentId));
              ref.invalidate(standingsByTournamentProvider(tournamentId));
              ref.invalidate(upcomingMatchesProvider(tournamentId));
              ref.invalidate(recentResultsProvider(tournamentId));
              ref.invalidate(liveMatchesByTournamentProvider(tournamentId));
              ref.invalidate(liveMatchesStreamProvider(tournamentId));
              ref.invalidate(goldenBootProvider(tournamentId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tournament header
                  _TournamentHeader(
                    name: tournament.name,
                    seasonYear: tournament.seasonYear,
                    status: tournament.status,
                  ),

                  // Quick navigation
                  _QuickNav(tournamentId: tournamentId),

                  const Divider(height: 32),

                  // Table section only for league format
                  if (tournament.format == 'league') ...[
                    _SectionHeader(
                      title: 'League Table',
                      onViewAll: () => context.push('/tournament/$tournamentId/standings'),
                    ),
                    _StandingsSection(tournamentId: tournamentId),

                    const Divider(height: 32),
                  ],

                  // Live Matches section (only shown if there are live matches)
                  _LiveSection(tournamentId: tournamentId),

                  // Upcoming Fixtures section
                  _SectionHeader(
                    title: 'Upcoming Fixtures',
                    onViewAll: () => context.push('/tournament/$tournamentId/fixtures'),
                  ),
                  _UpcomingSection(tournamentId: tournamentId),

                  const Divider(height: 32),

                  // Recent Results section
                  _SectionHeader(
                    title: 'Recent Results',
                    onViewAll: () => context.push('/tournament/$tournamentId/results'),
                  ),
                  _ResultsSection(tournamentId: tournamentId),

                  const SizedBox(height: 32),
                ],
              ),
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

class _TournamentHeader extends StatelessWidget {
  final String name;
  final int seasonYear;
  final TournamentStatus status;

  const _TournamentHeader({
    required this.name,
    required this.seasonYear,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.2),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Season $seasonYear',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _QuickNav extends ConsumerWidget {
  final String tournamentId;

  const _QuickNav({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.4,
            children: [
              _NavButton(
                icon: Icons.bar_chart_rounded,
                label: 'Standings',
                onTap: () => context.push('/tournament/$tournamentId/standings'),
              ),
              _NavButton(
                icon: Icons.calendar_month_rounded,
                label: 'Fixtures',
                onTap: () => context.push('/tournament/$tournamentId/fixtures'),
              ),
              _NavButton(
                icon: Icons.scoreboard_rounded,
                label: 'Results',
                onTap: () => context.push('/tournament/$tournamentId/results'),
              ),
              _NavButton(
                icon: Icons.groups_rounded,
                label: 'Teams',
                onTap: () => context.push('/tournament/$tournamentId/teams'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavButton(
            icon: Icons.emoji_events_rounded,
            label: 'Golden Boot',
            onTap: () => context.push('/tournament/$tournamentId/golden-boot'),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({
    required this.title,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }
}

class _StandingsSection extends ConsumerWidget {
  final String tournamentId;

  const _StandingsSection({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsByTournamentProvider(tournamentId));

    return standingsAsync.when(
      data: (standings) {
        if (standings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No standings yet'),
          );
        }

        return CompactStandingsTable(
          standings: standings,
          maxTeams: 5,
          onViewAll: () => context.push('/tournament/$tournamentId/standings'),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading standings: $e'),
      ),
    );
  }
}

class _LiveSection extends ConsumerWidget {
  final String tournamentId;

  const _LiveSection({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(liveMatchesStreamProvider(tournamentId));
    final canEdit = ref.watch(canEditTournamentProvider(tournamentId));

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            _SectionHeader(
              title: 'LIVE',
              onViewAll: null,
            ),
            ...matches.map((match) => MatchCard(
              match: match,
              onTap: canEdit
                  ? () => context.push(
                        match.isLive
                            ? '/admin/live-match/${match.id}'
                            : '/admin/tournaments/$tournamentId/matches/${match.id}/result',
                      )
                  : null,
            )),
            const Divider(height: 32),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _UpcomingSection extends ConsumerWidget {
  final String tournamentId;

  const _UpcomingSection({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(upcomingMatchesProvider(tournamentId));
    final canEdit = ref.watch(canEditTournamentProvider(tournamentId));

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No upcoming fixtures'),
          );
        }

        return Column(
          children: matches
              .where((match) => !match.isLive)
              .take(3)
              .map((match) => MatchCard(
                    match: match,
                    onTap: canEdit
                        ? () => context.push(
                              match.isLive
                                  ? '/admin/live-match/${match.id}'
                                  : '/admin/tournaments/$tournamentId/matches/${match.id}/result',
                            )
                        : null,
                  ))
              .toList(),
        );
      },

      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading fixtures: $e'),
      ),
    );
  }
}

class _ResultsSection extends ConsumerWidget {
  final String tournamentId;

  const _ResultsSection({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(recentResultsProvider(tournamentId));
    final canEdit = ref.watch(canEditTournamentProvider(tournamentId));

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No results yet'),
          );
        }

        return Column(
          children: matches
              .where((match) => !match.isLive)
              .take(3)
              .map((match) => MatchCard(
                    match: match,
                    showDate: true,
                    onTap: canEdit
                        ? () => context.push(
                              match.isLive
                                  ? '/admin/live-match/${match.id}'
                                  : '/admin/tournaments/$tournamentId/matches/${match.id}/result',
                            )
                        : null,
                  ))
              .toList(),
        );
      },

      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading results: $e'),
      ),
    );
  }
}
