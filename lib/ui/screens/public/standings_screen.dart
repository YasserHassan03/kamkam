import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/standing_providers.dart';
import '../../../providers/tournament_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';
import '../../widgets/standings/standings_table.dart';

/// Full league standings screen
class StandingsScreen extends ConsumerWidget {
  final String tournamentId;

  const StandingsScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(tournamentId));
    final standingsAsync = ref.watch(standingsByTournamentProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: tournamentAsync.maybeWhen(
          data: (t) => Text(t?.name ?? 'Standings'),
          orElse: () => const Text('Standings'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(standingsByTournamentProvider(tournamentId));
        },
        child: standingsAsync.when(
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
        ),
      ),
    );
  }
}
