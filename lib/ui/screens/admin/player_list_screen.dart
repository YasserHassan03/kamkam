import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/player.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/team_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Screen for managing players in a team
class PlayerListScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String teamId;

  const PlayerListScreen({
    super.key,
    required this.tournamentId,
    required this.teamId,
  });

  @override
  ConsumerState<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends ConsumerState<PlayerListScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-load players to avoid hanging - let provider handle errors naturally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Just trigger the load, errors will be handled by the provider's when() method
      ref.read(playersByTeamProvider(widget.teamId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamByIdProvider(widget.teamId));
    final playersAsync = ref.watch(playersByTeamProvider(widget.teamId));

    return Scaffold(
      appBar: AppBar(
        title: teamAsync.when(
          data: (team) => Text(team?.name ?? 'Players'),
          loading: () => const Text('Players'),
          error: (_, __) => const Text('Players'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/tournaments/${widget.tournamentId}');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(playersByTeamProvider(widget.teamId));
          // Wait for refresh with timeout
          try {
            await ref.read(playersByTeamProvider(widget.teamId).future)
                .timeout(const Duration(seconds: 10));
          } on TimeoutException {
            // Timeout handled silently
          } catch (e) {
            debugPrint('Error refreshing players: $e');
          }
        },
        child: playersAsync.when(
          data: (players) {
            if (players.isEmpty) {
              return Center(
                child: EmptyStateWidget(
                  icon: Icons.person_add,
                  title: 'No Players',
                  subtitle: 'Add players to this team',
                  action: FilledButton.icon(
                    onPressed: () => _showAddPlayerDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Player'),
                  ),
                ),
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        player.playerNumber?.toString() ?? '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(player.name),
                    subtitle: Text('Goals: ${player.goals?.toString() ?? '-'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditPlayerDialog(context, ref, player),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _confirmDeletePlayer(context, ref, player),
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
            onRetry: () {
              ref.invalidate(playersByTeamProvider(widget.teamId));
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPlayerDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddPlayerDialog(BuildContext context, WidgetRef ref) {
    _showPlayerDialog(
      context: context,
      ref: ref,
      title: 'Add Player',
      onSave: (name, playerNumber, goals) async {
        final player = Player(
          id: '',
          teamId: widget.teamId,
          name: name,
          playerNumber: playerNumber,
          goals: goals,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ref.read(createPlayerProvider(CreatePlayerRequest(player)).future);
        ref.invalidate(playersByTeamProvider(widget.teamId));
      },
    );
  }

  void _showEditPlayerDialog(BuildContext context, WidgetRef ref, Player player) {
    _showPlayerDialog(
      context: context,
      ref: ref,
      title: 'Edit Player',
      initialName: player.name,
      initialPlayerNumber: player.playerNumber,
      initialGoals: player.goals,
      onSave: (name, playerNumber, goals) async {
        final updated = player.copyWith(
          name: name,
          playerNumber: playerNumber,
          goals: goals,
        );
        await ref.read(updatePlayerProvider(UpdatePlayerRequest(updated)).future);
        ref.invalidate(playersByTeamProvider(widget.teamId));
      },
    );
  }

  void _showPlayerDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    String initialName = '',
    int? initialPlayerNumber,
    int? initialGoals,
    required Future<void> Function(String name, int? playerNumber, int? goals) onSave,
  }) {
    final nameController = TextEditingController(text: initialName);
    final numberController = TextEditingController(
      text: initialPlayerNumber?.toString() ?? '',
    );
    final goalsController = TextEditingController(
      text: initialGoals?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Player Number',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: goalsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Goals',
                    prefixIcon: Icon(Icons.sports_soccer),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  return;
                }

                Navigator.pop(context);
                try {
                  await onSave(
                    nameController.text.trim(),
                    int.tryParse(numberController.text),
                    int.tryParse(goalsController.text),
                  );
                } catch (e) {
                  // Error handled silently
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlayer(BuildContext context, WidgetRef ref, Player player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Player'),
        content: Text('Remove ${player.name} from the team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(deletePlayerProvider(DeletePlayerRequest(player.id, player.teamId)).future);
                ref.invalidate(playersByTeamProvider(player.teamId));
              } catch (e) {
                // Error handled silently
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
