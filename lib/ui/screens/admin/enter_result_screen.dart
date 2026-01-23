import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/team_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Screen for entering match results with standings update
class EnterResultScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;

  const EnterResultScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  @override
  ConsumerState<EnterResultScreen> createState() => _EnterResultScreenState();
}

class _EnterResultScreenState extends ConsumerState<EnterResultScreen> {
  int _homeScore = 0;
  int _awayScore = 0;
  bool _isLoading = false;

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(
        updateMatchResultProvider(UpdateResultRequest(
          matchId: widget.matchId,
          tournamentId: widget.tournamentId,
          homeGoals: _homeScore,
          awayGoals: _awayScore,
        )).future,
      );

      if (!mounted) return;

      if (result.success) {
        context.go('/admin/tournaments/${widget.tournamentId}');
      }
    } catch (e) {
      // Error handled silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));
    final teamsAsync = ref.watch(teamsByTournamentProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Result'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/admin/tournaments/${widget.tournamentId}'),
        ),
      ),
      body: matchAsync.when(
        data: (match) {
          if (match == null) {
            return const Center(child: Text('Match not found'));
          }

          // Initialize scores from match if set
          if (match.homeGoals != null && _homeScore == 0 && _awayScore == 0) {
            _homeScore = match.homeGoals!;
            _awayScore = match.awayGoals ?? 0;
          }

          return teamsAsync.when(
            data: (teams) {
              final homeTeam = teams.firstWhere(
                (t) => t.id == match.homeTeamId,
                orElse: () => teams.first,
              );
              final awayTeam = teams.firstWhere(
                (t) => t.id == match.awayTeamId,
                orElse: () => teams.last,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Match Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (match.matchday != null)
                              Text(
                                'Matchday ${match.matchday}',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            if (match.venue != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.location_on, size: 14),
                                    const SizedBox(width: 4),
                                    Text(match.venue!),
                                  ],
                                ),
                              ),
                            if (match.kickoffTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatDateTime(match.kickoffTime!),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Score Entry
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Home Team
                        Expanded(
                          child: Column(
                            children: [
                              _TeamDisplay(
                                name: homeTeam.name,
                                logoUrl: homeTeam.logoUrl,
                                isHome: true,
                              ),
                              const SizedBox(height: 16),
                              _ScoreCounter(
                                score: _homeScore,
                                enabled: !_isLoading,
                                onIncrement: () => setState(() => _homeScore++),
                                onDecrement: () {
                                  if (_homeScore > 0) {
                                    setState(() => _homeScore--);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        // VS
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 40,
                          ),
                          child: Text(
                            'VS',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),

                        // Away Team
                        Expanded(
                          child: Column(
                            children: [
                              _TeamDisplay(
                                name: awayTeam.name,
                                logoUrl: awayTeam.logoUrl,
                                isHome: false,
                              ),
                              const SizedBox(height: 16),
                              _ScoreCounter(
                                score: _awayScore,
                                enabled: !_isLoading,
                                onIncrement: () => setState(() => _awayScore++),
                                onDecrement: () {
                                  if (_awayScore > 0) {
                                    setState(() => _awayScore--);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Result Preview
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Final Score',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_homeScore - $_awayScore',
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getResultText(homeTeam.name, awayTeam.name),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: _getResultColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Info Text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Submitting this result will automatically update the tournament standings.',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _handleSubmit,
                        icon: _isLoading 
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                        label: Text(_isLoading ? 'Saving...' : 'Save Result'),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const LoadingWidget(),
            error: (e, _) => AppErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(teamsByTournamentProvider(widget.tournamentId)),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(matchByIdProvider(widget.matchId)),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getResultText(String homeTeam, String awayTeam) {
    if (_homeScore > _awayScore) {
      return '$homeTeam wins!';
    } else if (_awayScore > _homeScore) {
      return '$awayTeam wins!';
    } else {
      return 'Draw';
    }
  }

  Color _getResultColor() {
    if (_homeScore > _awayScore || _awayScore > _homeScore) {
      return Colors.green;
    }
    return Colors.orange;
  }
}

class _TeamDisplay extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool isHome;

  const _TeamDisplay({
    required this.name,
    this.logoUrl,
    required this.isHome,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isHome ? 'HOME' : 'AWAY',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 32,
          backgroundImage: logoUrl != null ? NetworkImage(logoUrl!) : null,
          child: logoUrl == null 
            ? Text(
                name[0].toUpperCase(),
                style: const TextStyle(fontSize: 24),
              )
            : null,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ScoreCounter extends StatelessWidget {
  final int score;
  final bool enabled;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ScoreCounter({
    required this.score,
    required this.enabled,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: enabled ? onIncrement : null,
          icon: const Icon(Icons.add),
          iconSize: 32,
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            score.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        IconButton.outlined(
          onPressed: enabled && score > 0 ? onDecrement : null,
          icon: const Icon(Icons.remove),
          iconSize: 32,
        ),
      ],
    );
  }
}
