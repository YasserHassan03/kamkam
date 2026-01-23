import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../data/models/match.dart';
import '../../../core/constants/enums.dart';
import '../../widgets/common/loading_error_widgets.dart';
import '../../widgets/match/match_card.dart';

/// All fixtures screen grouped by matchday
class FixturesScreen extends ConsumerWidget {
  final String tournamentId;

  const FixturesScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(tournamentId));
    final matchesAsync = ref.watch(matchesByTournamentProvider(tournamentId));
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      appBar: AppBar(
        title: tournamentAsync.maybeWhen(
          data: (t) => Text(t?.name ?? 'Fixtures'),
          orElse: () => const Text('Fixtures'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(matchesByTournamentProvider(tournamentId));
        },
        child: matchesAsync.when(
          data: (matches) {
            if (matches.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.calendar_month,
                title: 'No Fixtures Yet',
                subtitle: 'Fixtures will appear once they are scheduled',
              );
            }

            // Filter to show only scheduled matches
            final fixtures = matches.where((m) => 
                m.status == MatchStatus.scheduled || 
                m.status == MatchStatus.postponed).toList();
            
            if (fixtures.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.check_circle,
                title: 'All Matches Played',
                subtitle: 'Check out the results!',
              );
            }

            // Group by matchday
            final Map<int, List<Match>> grouped = {};
            for (final match in fixtures) {
              final day = match.matchday ?? 0;
              grouped.putIfAbsent(day, () => []).add(match);
            }

            final sortedDays = grouped.keys.toList()..sort();

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: sortedDays.length,
              itemBuilder: (context, index) {
                final matchday = sortedDays[index];
                final dayMatches = grouped[matchday]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MatchdayHeader(matchday: matchday),
                    ...dayMatches.map((match) => MatchCard(
                      match: match,
                      showVenue: true,
                      onTap: isAuthenticated
                          ? () => context.push('/admin/tournaments/$tournamentId/matches/${match.id}/result')
                          : null,
                    )),
                  ],
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
    );
  }
}

class _MatchdayHeader extends StatelessWidget {
  final int matchday;

  const _MatchdayHeader({required this.matchday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(top: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Text(
        matchday > 0 ? 'Matchday $matchday' : 'Unscheduled',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
