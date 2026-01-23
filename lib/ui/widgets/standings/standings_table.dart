import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/standing.dart';
import '../../../core/constants/enums.dart';

/// League standings table widget with sticky header
/// Optimized for mobile screens with clear points and GD display
class StandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final bool showFullStats;
  final Function(Standing)? onTeamTap;

  const StandingsTable({
    super.key,
    required this.standings,
    this.showFullStats = true,
    this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const Center(
        child: Text('No standings available'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        child: DataTable(
          columnSpacing: 12,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.surface,
          ),
          columns: [
            const DataColumn(
              label: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text('Team', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text('P', style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true,
            ),
            if (showFullStats) ...[
              const DataColumn(
                label: Text('W', style: TextStyle(fontWeight: FontWeight.bold)),
                numeric: true,
              ),
              const DataColumn(
                label: Text('D', style: TextStyle(fontWeight: FontWeight.bold)),
                numeric: true,
              ),
              const DataColumn(
                label: Text('L', style: TextStyle(fontWeight: FontWeight.bold)),
                numeric: true,
              ),
              const DataColumn(
                label: Text('GF', style: TextStyle(fontWeight: FontWeight.bold)),
                numeric: true,
              ),
              const DataColumn(
                label: Text('GA', style: TextStyle(fontWeight: FontWeight.bold)),
                numeric: true,
              ),
            ],
            const DataColumn(
              label: Text('GD', style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true,
            ),
            const DataColumn(
              label: Text('Pts', style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true,
            ),
            // ...existing code...
          ],
          rows: standings.asMap().entries.map((entry) {
            final index = entry.key;
            final standing = entry.value;
            final position = standing.position ?? (index + 1);

            return DataRow(
              onSelectChanged: onTeamTap != null 
                  ? (_) => onTeamTap!(standing) 
                  : null,
              cells: [
                DataCell(_PositionCell(position: position)),
                DataCell(
                  _TeamNameCell(
                    teamName: standing.team?.name ?? 'Unknown',
                    shortName: standing.team?.shortName,
                  ),
                ),
                DataCell(Text('${standing.played}')),
                if (showFullStats) ...[
                  DataCell(Text('${standing.won}')),
                  DataCell(Text('${standing.drawn}')),
                  DataCell(Text('${standing.lost}')),
                  DataCell(Text('${standing.goalsFor}')),
                  DataCell(Text('${standing.goalsAgainst}')),
                ],
                DataCell(_GoalDifferenceCell(gd: standing.goalDifference)),
                DataCell(_PointsCell(points: standing.points)),
                // ...existing code...
              ],
            );
          }).toList(),
        ),
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

  const _PositionCell({required this.position});

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    
    // Top positions get highlighted
    if (position == 1) {
      bgColor = AppTheme.primaryColor;
    } else if (position <= 3) {
      bgColor = AppTheme.primaryColor.withOpacity(0.5);
    }

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

    return Text(
      '$position',
      style: const TextStyle(fontWeight: FontWeight.w500),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Text(
        teamName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
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
        fontWeight: FontWeight.w500,
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
        fontSize: 16,
      ),
    );
  }
}

