import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/match.dart';
import '../../../core/constants/enums.dart';

/// Modern match card widget for displaying fixture/result
class MatchCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasResult = match.hasResult;
    
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Date and status row
                if (showDate) _buildDateRow(context),
                
                if (showDate) const SizedBox(height: 14),
                
                // Teams and score row
                _buildTeamsRow(context),
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
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

  Widget _buildTeamsRow(BuildContext context) {
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
            hasResult 
                ? '${match.homeGoals} - ${match.awayGoals}'
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
}

class _StatusBadge extends StatelessWidget {
  final MatchStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case MatchStatus.scheduled:
        color = const Color(0xFF3366FF);
        icon = Icons.schedule;
      case MatchStatus.inProgress:
        color = const Color(0xFFFFB84D);
        icon = Icons.play_circle;
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
