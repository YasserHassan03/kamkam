import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/team_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../data/models/team.dart';
import '../../../data/models/player.dart';
import '../../widgets/common/loading_error_widgets.dart';
import '../../widgets/common/follow_button.dart';

/// Screen showing all teams in a tournament and their rosters
class TeamsScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const TeamsScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsByTournamentProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams & Rosters'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search teams...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Teams list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(teamsByTournamentProvider(widget.tournamentId));
              },
              child: teamsAsync.when(
                data: (teams) {
                  final filteredTeams = teams
                      .where((t) => t.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList();

                  if (filteredTeams.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off_rounded,
                              size: 64, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No teams in this tournament'
                                : 'No teams match "$_searchQuery"',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTeams.length,
                    itemBuilder: (context, index) {
                      return _TeamRosterCard(team: filteredTeams[index]);
                    },
                  );
                },
                loading: () => const LoadingWidget(),
                error: (e, _) => AppErrorWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(teamsByTournamentProvider(widget.tournamentId)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamRosterCard extends ConsumerWidget {
  final Team team;

  const _TeamRosterCard({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: team.logoUrl != null
            ? CircleAvatar(
                backgroundImage: NetworkImage(team.logoUrl!),
                radius: 16,
              )
            : CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                radius: 16,
                child: Text(
                  team.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        title: Text(
          team.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(team.shortName ?? ''),
        trailing: FollowButton(teamId: team.id),
        children: [
          _RosterList(teamId: team.id),
        ],
      ),
    );
  }
}

class _RosterList extends ConsumerWidget {
  final String teamId;

  const _RosterList({required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersByTeamProvider(teamId));

    return playersAsync.when(
      data: (players) {
        if (players.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No roster submitted yet'),
          );
        }

        // Sort players by number if available
        final sortedPlayers = [...players];
        sortedPlayers.sort((a, b) {
          if (a.playerNumber == null) return 1;
          if (b.playerNumber == null) return -1;
          return a.playerNumber!.compareTo(b.playerNumber!);
        });

        return Column(
          children: [
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedPlayers.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final player = sortedPlayers[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      player.playerNumber?.toString() ?? '-',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(player.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports_soccer, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        (player.goals ?? 0).toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
      ),
    );
  }
}
