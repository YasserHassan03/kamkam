import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/standing.dart';

/// Professional league standings table
/// Designed to look like real football league tables
class StandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final bool showFullStats;
  final Function(Standing)? onTeamTap;
  final int? qualifiersPerGroup;

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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.leaderboard_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No standings available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _ProfessionalStandingsTable(
      standings: standings,
      showFullStats: showFullStats,
      onTeamTap: onTeamTap,
      qualifiersPerGroup: qualifiersPerGroup,
    );
  }
}

/// Compact standings table for overview
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.table_chart_rounded, size: 18),
                label: const Text('View Full Table'),
              ),
            ),
          ),
      ],
    );
  }
}

/// Professional looking standings table
class _ProfessionalStandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final bool showFullStats;
  final Function(Standing)? onTeamTap;
  final int? qualifiersPerGroup;

  const _ProfessionalStandingsTable({
    required this.standings,
    required this.showFullStats,
    this.onTeamTap,
    this.qualifiersPerGroup,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header
            Container(
              color: isDark 
                  ? AppTheme.navyLight.withValues(alpha: 0.5)
                  : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Position column
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Team column - takes remaining space
                  Expanded(
                    child: Text(
                      'Team',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  // Stats columns - fixed widths
                  _HeaderCell('P', width: 32),
                  if (showFullStats) ...[
                    _HeaderCell('W', width: 32),
                    _HeaderCell('D', width: 32),
                    _HeaderCell('L', width: 32),
                  ],
                  _HeaderCell('GD', width: 36),
                  _HeaderCell('Pts', width: 36, bold: true),
                ],
              ),
            ),
            
            // Rows
            ...standings.asMap().entries.map((entry) {
              final index = entry.key;
              final standing = entry.value;
              final position = standing.position ?? (index + 1);
              final isQualifying = qualifiersPerGroup != null && position <= qualifiersPerGroup!;
              final isChampion = position == 1;
              
              return Material(
                color: index.isEven 
                    ? Colors.transparent 
                    : (isDark 
                        ? Colors.white.withValues(alpha: 0.02) 
                        : Colors.black.withValues(alpha: 0.02)),
                child: InkWell(
                  onTap: onTeamTap != null ? () => onTeamTap!(standing) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isChampion 
                              ? AppTheme.primaryGreen 
                              : (isQualifying 
                                  ? AppTheme.primaryGreen.withValues(alpha: 0.5) 
                                  : Colors.transparent),
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Position
                        SizedBox(
                          width: 28,
                          child: _PositionIndicator(
                            position: position,
                            isQualifying: isQualifying,
                            isChampion: isChampion,
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Team Name
                        Expanded(
                          child: Text(
                            standing.team?.name ?? 'Team ${standing.teamId.substring(0, 4)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isChampion ? FontWeight.w700 : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Played
                        _StatCell('${standing.played}', width: 32),
                        
                        // W D L
                        if (showFullStats) ...[
                          _StatCell('${standing.won}', width: 32),
                          _StatCell('${standing.drawn}', width: 32),
                          _StatCell('${standing.lost}', width: 32),
                        ],
                        
                        // Goal Difference
                        SizedBox(
                          width: 36,
                          child: _GoalDifferenceText(standing.goalDifference),
                        ),
                        
                        // Points
                        SizedBox(
                          width: 36,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: isChampion 
                                  ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${standing.points}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isChampion ? AppTheme.primaryGreen : null,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final bool bold;

  const _HeaderCell(this.text, {required this.width, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: Theme.of(context).colorScheme.outline,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String text;
  final double width;

  const _StatCell(this.text, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PositionIndicator extends StatelessWidget {
  final int position;
  final bool isQualifying;
  final bool isChampion;

  const _PositionIndicator({
    required this.position,
    required this.isQualifying,
    required this.isChampion,
  });

  @override
  Widget build(BuildContext context) {
    if (isChampion) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppTheme.primaryGreen,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$position',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      );
    }
    
    if (isQualifying) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$position',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppTheme.primaryGreen,
          ),
        ),
      );
    }

    return SizedBox(
      width: 24,
      child: Text(
        '$position',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.outline,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _GoalDifferenceText extends StatelessWidget {
  final int gd;

  const _GoalDifferenceText(this.gd);

  @override
  Widget build(BuildContext context) {
    final isPositive = gd > 0;
    final isNegative = gd < 0;
    
    return Text(
      isPositive ? '+$gd' : '$gd',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: isPositive 
            ? AppTheme.winColor 
            : (isNegative ? AppTheme.lossColor : null),
      ),
      textAlign: TextAlign.center,
    );
  }
}
