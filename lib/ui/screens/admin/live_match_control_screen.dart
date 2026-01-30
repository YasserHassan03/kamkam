import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/match.dart';
import '../../../data/models/match_event.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/match_event_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../data/datasources/supabase_match_repository.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/player_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';
import '../../widgets/match/match_clock.dart';

/// Admin screen for controlling live matches
class LiveMatchControlScreen extends ConsumerStatefulWidget {
  final String matchId;

  const LiveMatchControlScreen({super.key, required this.matchId});

  @override
  ConsumerState<LiveMatchControlScreen> createState() =>
      _LiveMatchControlScreenState();
}

class _LiveMatchControlScreenState extends ConsumerState<LiveMatchControlScreen> {
  final _minuteController = TextEditingController();
  String? _selectedTeamId;
  String? _selectedPlayerId;
  String? _selectedPlayerName;
  bool _isProcessing = false;

  @override
  void dispose() {
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Match Control'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: matchAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stack) => AppErrorWidget(message: error.toString()),
        data: (match) {
          if (match == null) {
            return const Center(child: Text('Match not found'));
          }

          // PERMISSION CHECK
          final canEdit = ref.watch(canEditTournamentProvider(match.tournamentId));
          if (!canEdit) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Permission denied: You do not own this tournament',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              ),
            );
          }

          return _buildContent(match);
        },
      ),
    );
  }

  Widget _buildContent(Match match) {
    final eventsAsync = ref.watch(matchEventsStreamProvider(widget.matchId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Match header with teams and score
          _buildMatchHeader(match),
          const SizedBox(height: 24),

          // Match status controls
          _buildStatusControls(match),
          const SizedBox(height: 24),

          // Add goal section (only if match is live)
          if (match.isLive) ...[
            _buildAddGoalSection(match),
            const SizedBox(height: 24),
          ],

          // Goal events list
          _buildGoalEventsList(match, eventsAsync),
        ],
      ),
    );
  }

  Widget _buildMatchHeader(Match match) {
    final homeTeamName = match.homeTeam?.name ?? 'Home';
    final awayTeamName = match.awayTeam?.name ?? 'Away';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Live indicator
            if (match.isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Match Clock
            MatchClock(
              match: match,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            // Teams and score
            Row(
              children: [
                Expanded(
                  child: Text(
                    homeTeamName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${match.homeGoals ?? 0} - ${match.awayGoals ?? 0}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    awayTeamName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusControls(Match match) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatusButton(
                    label: match.status == MatchStatus.scheduled ? 'Start Match' : (match.isClockRunning ? 'Pause Clock' : 'Resume Clock'),
                    icon: match.status == MatchStatus.scheduled ? Icons.play_arrow : (match.isClockRunning ? Icons.pause : Icons.play_arrow),
                    color: match.isClockRunning ? Colors.orange : Colors.green,
                    enabled: match.status == MatchStatus.scheduled || (match.status == MatchStatus.inProgress),
                    onPressed: () {
                      if (match.status == MatchStatus.scheduled) {
                        _startMatch(match);
                      } else {
                        _toggleClock(match);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusButton(
                    label: 'End Match',
                    icon: Icons.stop,
                    color: Colors.red,
                    enabled: match.isLive,
                    onPressed: () => _endMatch(match),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleClock(Match match) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(matchRepositoryProvider) as SupabaseMatchRepository;
      await repo.toggleMatchClock(match, !match.isClockRunning);
      
      ref.invalidate(matchByIdProvider(widget.matchId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(match.isClockRunning ? 'Clock paused' : 'Clock resumed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled && !_isProcessing ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : null,
        foregroundColor: enabled ? Colors.white : null,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildAddGoalSection(Match match) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Goal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Team selection
            Row(
              children: [
                Expanded(
                  child: _TeamSelectButton(
                    teamName: match.homeTeam?.name ?? 'Home',
                    isSelected: _selectedTeamId == match.homeTeamId,
                    onTap: () {
                      setState(() {
                        _selectedTeamId = match.homeTeamId;
                        _selectedPlayerName = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TeamSelectButton(
                    teamName: match.awayTeam?.name ?? 'Away',
                    isSelected: _selectedTeamId == match.awayTeamId,
                    onTap: () {
                      setState(() {
                        _selectedTeamId = match.awayTeamId;
                        _selectedPlayerName = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Player name and minute
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _selectedTeamId == null 
                      ? const TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Select Team First',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        )
                      : ref.watch(playersByTeamProvider(_selectedTeamId!)).when(
                          data: (players) {
                            if (players.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.person_off_rounded, size: 20, color: Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 8),
                                    const Flexible(
                                      child: Text(
                                        'No players (Score only)',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              value: _selectedPlayerId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Scorer',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              items: players.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              )).toList(),
                              onChanged: (value) {
                                final player = players.firstWhere((p) => p.id == value);
                                setState(() {
                                  _selectedPlayerId = value;
                                  _selectedPlayerName = player.name;
                                });
                              },
                            );
                          },
                          loading: () => const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (e, _) => const TextField(
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Error loading players',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minuteController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Minute",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add goal button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedTeamId != null && !_isProcessing
                    ? () => _addGoal(match)
                    : null,
                icon: const Icon(Icons.sports_soccer),
                label: const Text('Add Goal'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalEventsList(Match match, AsyncValue<List<MatchEvent>> eventsAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Events',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (events) {
                if (events.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No goals yet')),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final isHomeTeam = event.teamId == match.homeTeamId;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.sports_soccer,
                        color: isHomeTeam ? Colors.blue : Colors.orange,
                      ),
                      title: Text(event.playerName ?? 'Unknown'),
                      subtitle: Text(
                        isHomeTeam ? match.homeTeam?.name ?? 'Home' : match.awayTeam?.name ?? 'Away',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.minute != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text("${event.minute}'"),
                            ),
                          if (match.isLive)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteGoal(event, match),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startMatch(Match match) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(matchRepositoryProvider) as SupabaseMatchRepository;
      final updatedMatch = await repo.startMatch(widget.matchId);
      
      // Force refresh of all related data
      ref.invalidate(matchByIdProvider(widget.matchId));
      ref.invalidate(liveMatchesByTournamentProvider(updatedMatch.tournamentId));
      ref.invalidate(upcomingMatchesProvider(updatedMatch.tournamentId));
      ref.invalidate(matchesByTournamentProvider(updatedMatch.tournamentId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match started!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _endMatch(Match match) async {
    // Confirm before ending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Match?'),
        content: const Text('Are you sure you want to end this match? This will finalize the result.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Match'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final result = await ref.read(
        updateMatchResultProvider(UpdateResultRequest(
          matchId: widget.matchId,
          tournamentId: match.tournamentId,
          homeGoals: match.homeGoals ?? 0,
          awayGoals: match.awayGoals ?? 0,
        )).future,
      );

      if (mounted && result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match ended and standings updated!')),
        );
        context.pop(); // Go back after ending match
      } else if (mounted && !result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending match: ${result.error}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _addGoal(Match match) async {
    if (_selectedTeamId == null) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(matchEventRepositoryProvider);
      final event = MatchEvent(
        id: '',
        matchId: widget.matchId,
        teamId: _selectedTeamId,
        eventType: MatchEventType.goal,
        playerId: _selectedPlayerId,
        playerName: _selectedPlayerName,
        minute: int.tryParse(_minuteController.text),
      );
      await repo.createEvent(event);

      // Score is updated automatically by DB triggers

      // Clear form
      _minuteController.clear();
      setState(() {
        _selectedTeamId = null;
        _selectedPlayerId = null;
        _selectedPlayerName = null;
      });

      invalidateMatchProviders(ref, match.tournamentId);
      ref.invalidate(matchByIdProvider(widget.matchId));
      ref.invalidate(matchEventsProvider(widget.matchId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteGoal(MatchEvent event, Match match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Remove ${event.playerName ?? "this goal"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(matchEventRepositoryProvider);
      await repo.deleteEvent(event.id);

      // Score is updated automatically by DB triggers

      invalidateMatchProviders(ref, match.tournamentId);
      ref.invalidate(matchByIdProvider(widget.matchId));
      ref.invalidate(matchEventsProvider(widget.matchId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}

class _TeamSelectButton extends StatelessWidget {
  final String teamName;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeamSelectButton({
    required this.teamName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          teamName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
        ),
      ),
    );
  }
}
