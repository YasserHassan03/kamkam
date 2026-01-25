import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/standing.dart';

/// League standings table widget with sticky header
/// Optimized for mobile screens with clear points and GD display
class StandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final bool showFullStats;
  final Function(Standing)? onTeamTap;
  final int? qualifiersPerGroup; // For group stages: number of teams that qualify

  const StandingsTable({
    super.key,
    required this.standings,
    this.showFullStats = true,
    this.onTeamTap,
    this.qualifiersPerGroup,
  });

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const Center(
        child: Text('No standings available'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: _CustomStandingsTable(
        standings: standings,
        showFullStats: showFullStats,
        onTeamTap: onTeamTap,
        qualifiersPerGroup: qualifiersPerGroup,
      ),
    );
  }
}

/// Compact standings table for tournament overview
class CompactStandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final int maxTeams;
  final VoidCallback? onViewAll;

  const CompactStandingsTable({
    super.key,
    required this.standings,
    this.maxTeams = 5,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayStandings = standings.take(maxTeams).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StandingsTable(
          standings: displayStandings,
          showFullStats: false,
        ),
        if (standings.length > maxTeams && onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('View Full Table'),
          ),
      ],
    );
  }
}

class _PositionCell extends StatelessWidget {
  final int position;
  final int? qualifiersPerGroup; // For group stages: highlight qualifying positions

  const _PositionCell({
    required this.position,
    this.qualifiersPerGroup,
  });

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    
    // Determine how many positions to highlight
    final highlightCount = qualifiersPerGroup ?? 3; // Default to top 3 if not specified
    
    // Top positions get highlighted
    // Position 1 gets full color, positions 2 through highlightCount get semi-transparent
    if (position <= highlightCount && highlightCount > 0) {
      if (position == 1) {
        bgColor = AppTheme.primaryColor;
      } else {
        bgColor = AppTheme.primaryColor.withOpacity(0.5);
      }
    }

    // Always use a container with fixed width for consistent alignment
    if (bgColor != null) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$position',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      );
    }

    // Plain text positions also use fixed width container for alignment
    return Container(
      width: 24,
      alignment: Alignment.centerLeft,
      child: Text(
        '$position',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _TeamNameCell extends StatelessWidget {
  final String teamName;
  final String? shortName;

  const _TeamNameCell({
    required this.teamName,
    this.shortName,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      teamName,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
    );
  }
}

class _GoalDifferenceCell extends StatelessWidget {
  final int gd;

  const _GoalDifferenceCell({required this.gd});

  @override
  Widget build(BuildContext context) {
    Color color;
    String prefix = '';

    if (gd > 0) {
      color = AppTheme.winColor;
      prefix = '+';
    } else if (gd < 0) {
      color = AppTheme.lossColor;
    } else {
      color = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;
    }

    return Text(
      '$prefix$gd',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class _PointsCell extends StatelessWidget {
  final int points;

  const _PointsCell({required this.points});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$points',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}

/// Custom standings table with better spacing and readability
class _CustomStandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final bool showFullStats;
  final Function(Standing)? onTeamTap;
  final int? qualifiersPerGroup;

  const _CustomStandingsTable({
    required this.standings,
    required this.showFullStats,
    this.onTeamTap,
    this.qualifiersPerGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text('#', style: _headerStyle(context))),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text('Team', style: _headerStyle(context)),
              ),
              SizedBox(width: 24, child: Center(child: Text('P', style: _headerStyle(context)))),
              if (showFullStats) ...[
                SizedBox(width: 24, child: Center(child: Text('W', style: _headerStyle(context)))),
                SizedBox(width: 24, child: Center(child: Text('D', style: _headerStyle(context)))),
                SizedBox(width: 24, child: Center(child: Text('L', style: _headerStyle(context)))),
                SizedBox(width: 28, child: Center(child: Text('GF', style: _headerStyle(context)))),
                SizedBox(width: 28, child: Center(child: Text('GA', style: _headerStyle(context)))),
              ],
              SizedBox(width: 32, child: Center(child: Text('GD', style: _headerStyle(context)))),
              SizedBox(width: 36, child: Center(child: Text('Pts', style: _headerStyle(context)))),
            ],
          ),
        ),
        // Data rows
        ...standings.asMap().entries.map((entry) {
          final index = entry.key;
          final standing = entry.value;
          final position = standing.position ?? (index + 1);

          return InkWell(
            onTap: onTeamTap != null ? () => onTeamTap!(standing) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: 28, child: _PositionCell(position: position, qualifiersPerGroup: qualifiersPerGroup)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _TeamNameCell(
                      teamName: standing.team?.name ?? 'Unknown',
                      shortName: standing.team?.shortName,
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Center(
                      child: Text('${standing.played}', style: _dataStyle(context)),
                    ),
                  ),
                  if (showFullStats) ...[
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('${standing.won}', style: _dataStyle(context)),
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('${standing.drawn}', style: _dataStyle(context)),
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('${standing.lost}', style: _dataStyle(context)),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Text('${standing.goalsFor}', style: _dataStyle(context)),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Text('${standing.goalsAgainst}', style: _dataStyle(context)),
                      ),
                    ),
                  ],
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: _GoalDifferenceCell(gd: standing.goalDifference),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: _PointsCell(points: standing.points),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  TextStyle _headerStyle(BuildContext context) {
    return TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
    );
  }

  TextStyle _dataStyle(BuildContext context) {
    return const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
  }
}

