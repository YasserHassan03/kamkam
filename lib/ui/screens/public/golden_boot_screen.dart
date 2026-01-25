import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/player_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

class GoldenBootScreen extends ConsumerWidget {
  final String tournamentId;

  const GoldenBootScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goldenBootAsync = ref.watch(goldenBootProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Golden Boot'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/tournament/$tournamentId');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(goldenBootProvider(tournamentId));
          try {
            await ref.read(goldenBootProvider(tournamentId).future);
          } catch (_) {
            // Error handled by UI state
          }
        },
        child: goldenBootAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return const Center(
                child: EmptyStateWidget(
                  icon: Icons.emoji_events_rounded,
                  title: 'No Players Yet',
                  subtitle: 'Add players to teams to see the golden boot table.',
                ),
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final rank = index + 1;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(entry.playerName),
                    subtitle: Text(entry.teamName),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.goals}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Goals',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const LoadingWidget(),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(goldenBootProvider(tournamentId)),
          ),
        ),
      ),
    );
  }
}

