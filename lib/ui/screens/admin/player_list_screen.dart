import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/player.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/team_providers.dart';
import '../../../providers/repository_providers.dart';
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
                        player.jerseyNumber?.toString() ?? '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(player.name),
                    subtitle: Text(player.position?.displayName ?? 'No position'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (player.isCaptain)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'C',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
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
      onSave: (name, position, jerseyNumber, isCaptain) async {
        final player = Player(
          id: '',
          teamId: widget.teamId,
          name: name,
          position: position,
          jerseyNumber: jerseyNumber,
          isCaptain: isCaptain,
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
      initialPosition: player.position,
      initialJerseyNumber: player.jerseyNumber,
      initialIsCaptain: player.isCaptain,
      onSave: (name, position, jerseyNumber, isCaptain) async {
        final updated = player.copyWith(
          name: name,
          position: position,
          jerseyNumber: jerseyNumber,
          isCaptain: isCaptain,
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
    PlayerPosition? initialPosition,
    int? initialJerseyNumber,
    bool initialIsCaptain = false,
    required Future<void> Function(String name, PlayerPosition? position, int? jerseyNumber, bool isCaptain) onSave,
  }) {
    final nameController = TextEditingController(text: initialName);
    PlayerPosition? selectedPosition = initialPosition;
    final jerseyController = TextEditingController(
      text: initialJerseyNumber?.toString() ?? '',
    );
    var isCaptain = initialIsCaptain;

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
                DropdownButtonFormField<PlayerPosition>(
                  value: selectedPosition,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    prefixIcon: Icon(Icons.sports_soccer),
                  ),
                  items: PlayerPosition.values.map((position) {
                    return DropdownMenuItem(
                      value: position,
                      child: Text(position.displayName),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedPosition = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: jerseyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jersey Number',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Team Captain'),
                  value: isCaptain,
                  onChanged: (value) => setState(() => isCaptain = value),
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
                    selectedPosition,
                    int.tryParse(jerseyController.text),
                    isCaptain,
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
