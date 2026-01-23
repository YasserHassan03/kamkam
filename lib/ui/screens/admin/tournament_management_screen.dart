import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/tournament.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/user_profile_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Admin screen for managing tournament visibility
class TournamentManagementScreen extends ConsumerWidget {
  const TournamentManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(allTournamentsProvider);
    final isAdmin = ref.watch(isUserAdminProvider);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tournament Management')),
        body: const Center(
          child: Text('Only admins can access this page'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Management'),
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
          // Refresh button for manual refresh
          Consumer(
            builder: (context, ref, _) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(allTournamentsProvider);
              },
            ),
          ),
        ],
      ),
      body: tournamentsAsync.when(
        data: (tournaments) {
          if (tournaments.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.emoji_events,
              title: 'No Tournaments',
              subtitle: 'No tournaments have been created yet',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Force refresh by invalidating the provider
              ref.invalidate(allTournamentsProvider);
              // Wait a moment for the refresh
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tournament.hiddenByAdmin
                          ? Colors.red.withValues(alpha: 0.2)
                          : tournament.status == TournamentStatus.draft
                              ? Theme.of(context).colorScheme.tertiaryContainer
                              : Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(
                        tournament.hiddenByAdmin
                            ? Icons.visibility_off
                            : tournament.status == TournamentStatus.draft
                                ? Icons.edit_note
                                : Icons.emoji_events,
                        color: tournament.hiddenByAdmin
                            ? Colors.red
                            : tournament.status == TournamentStatus.draft
                                ? Theme.of(context).colorScheme.onTertiaryContainer
                                : Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(tournament.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tournament.rules.type.displayName} • ${tournament.status.displayName} • ${tournament.visibility.displayName}',
                        ),
                        if (tournament.hiddenByAdmin)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_off,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Hidden from public',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: Consumer(
                      builder: (context, ref, _) {
                        // Watch the tournament to get the latest state
                        final tournamentAsync = ref.watch(tournamentByIdProvider(tournament.id));
                        final currentTournament = tournamentAsync.value ?? tournament;
                        final isVisible = !currentTournament.hiddenByAdmin;
                        
                        return Switch(
                          value: isVisible,
                          onChanged: (visible) async {
                            try {
                              // Optimistically update the UI
                              ref.invalidate(allTournamentsProvider);
                              ref.invalidate(tournamentByIdProvider(tournament.id));
                              
                              await ref.read(toggleTournamentVisibilityProvider((
                                tournamentId: tournament.id,
                                hidden: !visible,
                              )).future);
                              
                              // Invalidate again to ensure fresh data
                              ref.invalidate(allTournamentsProvider);
                              ref.invalidate(tournamentByIdProvider(tournament.id));
                              
                            } catch (e) {
                              // Revert on error
                              ref.invalidate(allTournamentsProvider);
                              ref.invalidate(tournamentByIdProvider(tournament.id));
                              
                            }
                          },
                          // Green when visible (on), red when hidden (off)
                          activeColor: Colors.green,
                          activeTrackColor: Colors.green.withValues(alpha: 0.5),
                          inactiveThumbColor: Colors.red,
                          inactiveTrackColor: Colors.red.withValues(alpha: 0.5),
                        );
                      },
                    ),
                    onTap: () => context.go('/admin/tournaments/${tournament.id}'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(allTournamentsProvider),
        ),
      ),
    );
  }
}
