import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/match.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/team_providers.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _scoresInitialized = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _dateTimeInitialized = false;

  Future<void> _updateMatchDateTime(Match match) async {
    if (_selectedDate == null) return;

    setState(() => _isLoading = true);

    try {
      final updated = match.copyWith(
        kickoffTime: _selectedDate,
      );
      
      await ref.read(updateMatchProvider(UpdateMatchRequest(updated)).future);
      
      if (!mounted) return;
      
      ref.invalidate(matchByIdProvider(widget.matchId));
      ref.invalidate(matchesByTournamentProvider(widget.tournamentId));
    } catch (e) {
      // Error handled silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
        data: (Match? match) {
          if (match == null) {
            return const Center(child: Text('Match not found'));
          }

          // Initialize scores from match if set (only once)
          if (!_scoresInitialized && match.homeGoals != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _homeScore = match.homeGoals ?? 0;
                  _awayScore = match.awayGoals ?? 0;
                  _scoresInitialized = true;
                });
              }
            });
          } else if (!_scoresInitialized) {
            _scoresInitialized = true;
          }

          // Initialize date and time from match if set (only once)
          if (!_dateTimeInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  if (match.kickoffTime != null) {
                    _selectedDate = match.kickoffTime!;
                    _selectedTime = TimeOfDay.fromDateTime(match.kickoffTime!);
                  }
                  _dateTimeInitialized = true;
                });
              }
            });
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
                child: Column(
                  children: [
                    // Match header with date/time
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Matchday badge
                          if (match.matchday != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Matchday ${match.matchday}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          
                          // Date/Time row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _DateTimeChip(
                                icon: Icons.calendar_today_rounded,
                                label: _selectedDate != null
                                    ? DateFormat('EEE, d MMM').format(_selectedDate!)
                                    : 'Set Date',
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate ?? DateTime.now(),
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      if (_selectedTime != null) {
                                        _selectedDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          _selectedTime!.hour,
                                          _selectedTime!.minute,
                                        );
                                      } else {
                                        _selectedDate = picked;
                                      }
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              _DateTimeChip(
                                icon: Icons.access_time_rounded,
                                label: _selectedTime != null
                                    ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Set Time',
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime ?? TimeOfDay.now(),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedTime = picked;
                                      final baseDate = _selectedDate ?? DateTime.now();
                                      _selectedDate = DateTime(
                                        baseDate.year,
                                        baseDate.month,
                                        baseDate.day,
                                        picked.hour,
                                        picked.minute,
                                      );
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_selectedDate != null && match.kickoffTime != _selectedDate)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextButton.icon(
                                onPressed: _isLoading ? null : () => _updateMatchDateTime(match),
                                icon: const Icon(Icons.save_rounded, size: 18),
                                label: const Text('Save Date/Time'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Score entry section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Teams and Score
                          Row(
                            children: [
                              // Home Team
                              Expanded(
                                child: _TeamScoreColumn(
                                  teamName: homeTeam.name,
                                  shortName: homeTeam.shortName,
                                  isHome: true,
                                  score: _homeScore,
                                  enabled: !_isLoading,
                                  onIncrement: () => setState(() => _homeScore++),
                                  onDecrement: () => setState(() {
                                    if (_homeScore > 0) _homeScore--;
                                  }),
                                ),
                              ),
                              
                              // VS divider
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 40),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        'VS',
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Away Team
                              Expanded(
                                child: _TeamScoreColumn(
                                  teamName: awayTeam.name,
                                  shortName: awayTeam.shortName,
                                  isHome: false,
                                  score: _awayScore,
                                  enabled: !_isLoading,
                                  onIncrement: () => setState(() => _awayScore++),
                                  onDecrement: () => setState(() {
                                    if (_awayScore > 0) _awayScore--;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _handleSubmit,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading 
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text('Save Result'),
                                    ],
                                  ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Result preview
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Final Score',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$_homeScore',
                                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: _homeScore > _awayScore 
                                            ? AppTheme.winColor 
                                            : null,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        '-',
                                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                          fontWeight: FontWeight.w300,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$_awayScore',
                                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: _awayScore > _homeScore 
                                            ? AppTheme.winColor 
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _ResultBadge(
                                  homeScore: _homeScore,
                                  awayScore: _awayScore,
                                  homeTeam: homeTeam.name,
                                  awayTeam: awayTeam.name,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Info note
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Standings will update automatically',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}

/// Date/Time selection chip
class _DateTimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateTimeChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Team score column
class _TeamScoreColumn extends StatelessWidget {
  final String teamName;
  final String? shortName;
  final bool isHome;
  final int score;
  final bool enabled;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _TeamScoreColumn({
    required this.teamName,
    this.shortName,
    required this.isHome,
    required this.score,
    required this.enabled,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Home/Away label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isHome ? 'HOME' : 'AWAY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Team name
        Text(
          teamName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (shortName != null) ...[
          const SizedBox(height: 2),
          Text(
            shortName!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
        const SizedBox(height: 20),
        
        // Score display with buttons
        Column(
          children: [
            // Increment button
            _ScoreButton(
              icon: Icons.add_rounded,
              enabled: enabled,
              onPressed: onIncrement,
              isPrimary: true,
            ),
            const SizedBox(height: 8),
            
            // Score display
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  score.toString(),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Decrement button
            _ScoreButton(
              icon: Icons.remove_rounded,
              enabled: enabled && score > 0,
              onPressed: onDecrement,
              isPrimary: false,
            ),
          ],
        ),
      ],
    );
  }
}

/// Score adjustment button
class _ScoreButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ScoreButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: enabled
            ? (isPrimary 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            size: 24,
            color: enabled
                ? (isPrimary 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// Result badge
class _ResultBadge extends StatelessWidget {
  final int homeScore;
  final int awayScore;
  final String homeTeam;
  final String awayTeam;

  const _ResultBadge({
    required this.homeScore,
    required this.awayScore,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;

    if (homeScore > awayScore) {
      text = '$homeTeam wins';
      color = AppTheme.winColor;
    } else if (awayScore > homeScore) {
      text = '$awayTeam wins';
      color = AppTheme.winColor;
    } else {
      text = 'Draw';
      color = AppTheme.drawColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
