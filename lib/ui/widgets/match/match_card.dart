import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/match.dart';
import '../../../data/models/match_event.dart';
import '../../../core/constants/enums.dart';
import '../../../providers/match_event_providers.dart';

/// Modern match card widget for displaying fixture/result
class MatchCard extends ConsumerStatefulWidget {
  final Match match;
  final VoidCallback? onTap;
  final bool showDate;

  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.showDate = true,
  });

  @override
  ConsumerState<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends ConsumerState<MatchCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasResult = match.hasResult;
    final hasGoals = (match.homeGoals ?? 0) > 0 || (match.awayGoals ?? 0) > 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: hasResult
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                ],
              ),
        border: Border.all(
          color: hasResult
              ? Colors.transparent
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Date and status row
                if (widget.showDate) _buildDateRow(context, match),
                
                if (widget.showDate) const SizedBox(height: 14),
                
                // Teams and score row
                _buildTeamsRow(context, match),

                // Expandable Goalscorers section
                if (hasGoals) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpanded ? 'Hide Scorers' : 'View Scorers',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isExpanded) _buildGoalscorersSection(context, match),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, Match match) {
    final dateStr = match.kickoffTime != null
        ? DateFormat('EEE, d MMM · HH:mm').format(match.kickoffTime!)
        : 'Date TBD';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (match.matchday != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Matchday ${match.matchday}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        Expanded(
          child: Center(
            child: Text(
              dateStr,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        _StatusBadge(status: match.status),
      ],
    );
  }

  Widget _buildTeamsRow(BuildContext context, Match match) {
    final homeTeamName = match.homeTeam?.name ?? 'Home Team';
    final awayTeamName = match.awayTeam?.name ?? 'Away Team';
    final hasResult = match.hasResult;

    return Row(
      children: [
        // Home team
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                homeTeamName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: hasResult && match.homeWin == true
                      ? AppTheme.winColor
                      : null,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (match.homeTeam?.shortName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    match.homeTeam!.shortName!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
        
        // Score - Modern design
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: hasResult
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                    ],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            (hasResult || match.isLive) 
                ? '${match.homeGoals ?? 0} - ${match.awayGoals ?? 0}'
                : 'VS',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        
        // Away team
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                awayTeamName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: hasResult && match.awayWin == true
                      ? AppTheme.winColor
                      : null,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (match.awayTeam?.shortName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    match.awayTeam!.shortName!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalscorersSection(BuildContext context, Match match) {
    final eventsAsync = ref.watch(matchEventsStreamProvider(match.id));

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();

        // Sort events by minute
        final sortedEvents = List<MatchEvent>.from(events)
          ..sort((a, b) => (a.minute ?? 0).compareTo(b.minute ?? 0));

        final homeScorers = sortedEvents.where((e) => e.teamId == match.homeTeamId).toList();
        final awayScorers = sortedEvents.where((e) => e.teamId == match.awayTeamId).toList();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Home Scorers
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: homeScorers.map((e) => _buildScorerItem(context, e, true)).toList(),
                ),
              ),
              const SizedBox(width: 24),
              // Away Scorers
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: awayScorers.map((e) => _buildScorerItem(context, e, false)).toList(),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildScorerItem(BuildContext context, MatchEvent event, bool isHome) {
    if (event.playerName == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isHome) ...[
            const Icon(Icons.sports_soccer, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              '${event.playerName} ${event.minute != null ? "(${event.minute}')" : ""}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isHome) ...[
            const SizedBox(width: 4),
            const Icon(Icons.sports_soccer, size: 12, color: Colors.white),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MatchStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // Use animated badge for live matches
    if (status == MatchStatus.inProgress) {
      return const _LiveBadge();
    }

    Color color;
    IconData icon;
    switch (status) {
      case MatchStatus.scheduled:
        color = const Color(0xFF3366FF);
        icon = Icons.schedule;
      case MatchStatus.inProgress:
        color = const Color(0xFFFF3B4A);
        icon = Icons.circle;
      case MatchStatus.finished:
        color = const Color(0xFF00D981);
        icon = Icons.check_circle;
      case MatchStatus.postponed:
        color = const Color(0xFFFF3B4A);
        icon = Icons.pause_circle;
      case MatchStatus.cancelled:
        color = const Color(0xFF6B7580);
        icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated LIVE badge with pulsing effect
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF3B4A);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2 * _animation.value),
                color.withValues(alpha: 0.1 * _animation.value),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.5 * _animation.value),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _animation.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5 * _animation.value),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact match list item
class MatchListTile extends StatelessWidget {
  final Match match;
  final VoidCallback? onTap;

  const MatchListTile({
    super.key,
    required this.match,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              match.homeTeam?.name ?? 'Home',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              match.hasResult 
                  ? '${match.homeGoals} - ${match.awayGoals}'
                  : 'VS',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              match.awayTeam?.name ?? 'Away',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: match.kickoffTime != null
          ? Text(
              DateFormat('d MMM, HH:mm').format(match.kickoffTime!),
              textAlign: TextAlign.center,
            )
          : null,
    );
  }
}
