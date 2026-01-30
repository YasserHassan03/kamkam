import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../core/constants/enums.dart';
import 'team.dart';

part 'match.g.dart';

/// Match model representing a fixture/game between two teams
@JsonSerializable(explicitToJson: true)
class Match extends Equatable {
  final String id;
  
  @JsonKey(name: 'tournament_id')
  final String tournamentId;
  
  @JsonKey(name: 'home_team_id')
  final String homeTeamId;
  
  @JsonKey(name: 'away_team_id')
  final String awayTeamId;
  
  final int? matchday;
  
  @JsonKey(name: 'kickoff_time')
  final DateTime? kickoffTime;
  
  @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
  final MatchStatus status;
  
  @JsonKey(name: 'home_goals')
  final int? homeGoals;
  
  @JsonKey(name: 'away_goals')
  final int? awayGoals;
  
  @JsonKey(name: 'previous_home_goals')
  final int? previousHomeGoals;
  
  @JsonKey(name: 'previous_away_goals')
  final int? previousAwayGoals;
  
  final String? notes;
  
  @JsonKey(name: 'home_penalty_goals')
  final int? homePenaltyGoals;
  
  @JsonKey(name: 'away_penalty_goals')
  final int? awayPenaltyGoals;
  
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @JsonKey(name: 'is_clock_running')
  final bool isClockRunning;

  @JsonKey(name: 'clock_start_time')
  final DateTime? clockStartTime;

  @JsonKey(name: 'accumulated_seconds')
  final int accumulatedSeconds;

  // Bracket-related fields
  @JsonKey(name: 'round_number')
  final int? roundNumber;

  @JsonKey(name: 'next_match_id')
  final String? nextMatchId;

  @JsonKey(name: 'home_seed')
  final int? homeSeed;

  @JsonKey(name: 'away_seed')
  final int? awaySeed;

  @JsonKey(name: 'home_qualifier')
  final String? homeQualifier;

  @JsonKey(name: 'away_qualifier')
  final String? awayQualifier;

  // Optional joined data
  @JsonKey(name: 'home_team', includeIfNull: false)
  final Team? homeTeam;
  
  @JsonKey(name: 'away_team', includeIfNull: false)
  final Team? awayTeam;

  const Match({
    required this.id,
    required this.tournamentId,
    required this.homeTeamId,
    required this.awayTeamId,
    this.matchday,
    this.kickoffTime,
    this.status = MatchStatus.scheduled,
    this.homeGoals,
    this.awayGoals,
    this.previousHomeGoals,
    this.previousAwayGoals,
    this.notes,
    this.homePenaltyGoals,
    this.awayPenaltyGoals,
    this.createdAt,
    this.updatedAt,
    this.roundNumber,
    this.nextMatchId,
    this.homeSeed,
    this.awaySeed,
    this.homeQualifier,
    this.awayQualifier,
    this.homeTeam,
    this.awayTeam,
    this.isClockRunning = false,
    this.clockStartTime,
    this.accumulatedSeconds = 0,
  });

  /// The total elapsed seconds of the match.
  /// If the clock is running, it adds the time since clockStartTime to accumulatedSeconds.
  int get elapsedSeconds {
    if (!isClockRunning || clockStartTime == null) {
      return accumulatedSeconds;
    }
    final now = DateTime.now();
    final diff = now.difference(clockStartTime!).inSeconds;
    return accumulatedSeconds + diff;
  }

  /// Whether this match has a result
  bool get hasResult => 
      status == MatchStatus.finished && homeGoals != null && awayGoals != null;

  /// Whether this match is currently live/in progress
  bool get isLive => status == MatchStatus.inProgress;

  /// Whether this is an upcoming match
  bool get isUpcoming => 
      status == MatchStatus.scheduled && 
      (kickoffTime == null || kickoffTime!.isAfter(DateTime.now()));

  /// Get the score as a string, including penalties if it's a draw
  String get scoreDisplay {
    if (!hasResult) return '- vs -';
    if (homeGoals == awayGoals && homePenaltyGoals != null && awayPenaltyGoals != null) {
      return '$homeGoals ($homePenaltyGoals) - $awayGoals ($awayPenaltyGoals)';
    }
    return '$homeGoals - $awayGoals';
  }

  /// Determine if home team won
  bool? get homeWin => hasResult ? homeGoals! > awayGoals! : null;

  /// Determine if away team won
  bool? get awayWin => hasResult ? awayGoals! > homeGoals! : null;

  /// Determine if it was a draw
  bool? get isDraw => hasResult ? homeGoals == awayGoals : null;

  factory Match.fromJson(Map<String, dynamic> json) {
    // Handle nested team data from joins
    final homeTeamData = json['home_team'];
    final awayTeamData = json['away_team'];
    
    // Safe string conversion helper
    String safeString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }
    
    // Safe DateTime parsing helper
    DateTime? safeDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is DateTime) return value;
        final str = value.toString();
        if (str.isEmpty) return null;
        return DateTime.parse(str);
      } catch (e) {
        return null;
      }
    }
    
    return Match(
      id: safeString(json['id'], ''),
      tournamentId: safeString(json['tournament_id'], ''),
      homeTeamId: safeString(json['home_team_id'], ''),
      awayTeamId: safeString(json['away_team_id'], ''),
      matchday: (json['matchday'] as num?)?.toInt(),
      kickoffTime: safeDateTime(json['kickoff_time']),
      status: _statusFromJson(json['status']?.toString() ?? 'scheduled'),
      homeGoals: (json['home_goals'] as num?)?.toInt(),
      awayGoals: (json['away_goals'] as num?)?.toInt(),
      homePenaltyGoals: (json['home_penalty_goals'] as num?)?.toInt(),
      awayPenaltyGoals: (json['away_penalty_goals'] as num?)?.toInt(),
      previousHomeGoals: (json['previous_home_goals'] as num?)?.toInt(),
      previousAwayGoals: (json['previous_away_goals'] as num?)?.toInt(),
      notes: json['notes']?.toString(),
      createdAt: safeDateTime(json['created_at']),
      updatedAt: safeDateTime(json['updated_at']),
      roundNumber: (json['round_number'] as num?)?.toInt(),
      nextMatchId: json['next_match_id']?.toString(),
      homeSeed: (json['home_seed'] as num?)?.toInt(),
      awaySeed: (json['away_seed'] as num?)?.toInt(),
      homeQualifier: json['home_qualifier']?.toString(),
      awayQualifier: json['away_qualifier']?.toString(),
      homeTeam: homeTeamData is Map<String, dynamic>
          ? Team.fromJson(homeTeamData)
          : null,
      awayTeam: awayTeamData is Map<String, dynamic>
          ? Team.fromJson(awayTeamData)
          : null,
      isClockRunning: json['is_clock_running'] == true,
      clockStartTime: safeDateTime(json['clock_start_time']),
      accumulatedSeconds: (json['accumulated_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => _$MatchToJson(this);

  Map<String, dynamic> toInsertJson() => {
    'tournament_id': tournamentId,
    'home_team_id': homeTeamId,
    'away_team_id': awayTeamId,
    'matchday': matchday,
    'kickoff_time': kickoffTime?.toIso8601String(),
    'status': status.jsonValue,
    'notes': notes,
  };

  Match copyWith({
    String? id,
    String? tournamentId,
    String? homeTeamId,
    String? awayTeamId,
    int? matchday,
    DateTime? kickoffTime,
    MatchStatus? status,
    int? homeGoals,
    int? awayGoals,
    int? homePenaltyGoals,
    int? awayPenaltyGoals,
    int? previousHomeGoals,
    int? previousAwayGoals,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? roundNumber,
    String? nextMatchId,
    int? homeSeed,
    int? awaySeed,
    String? homeQualifier,
    String? awayQualifier,
    Team? homeTeam,
    Team? awayTeam,
    bool? isClockRunning,
    DateTime? clockStartTime,
    int? accumulatedSeconds,
  }) {
    return Match(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      matchday: matchday ?? this.matchday,
      kickoffTime: kickoffTime ?? this.kickoffTime,
      status: status ?? this.status,
      homeGoals: homeGoals ?? this.homeGoals,
      awayGoals: awayGoals ?? this.awayGoals,
      homePenaltyGoals: homePenaltyGoals ?? this.homePenaltyGoals,
      awayPenaltyGoals: awayPenaltyGoals ?? this.awayPenaltyGoals,
      previousHomeGoals: previousHomeGoals ?? this.previousHomeGoals,
      previousAwayGoals: previousAwayGoals ?? this.previousAwayGoals,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roundNumber: roundNumber ?? this.roundNumber,
      nextMatchId: nextMatchId ?? this.nextMatchId,
      homeSeed: homeSeed ?? this.homeSeed,
      awaySeed: awaySeed ?? this.awaySeed,
      homeQualifier: homeQualifier ?? this.homeQualifier,
      awayQualifier: awayQualifier ?? this.awayQualifier,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      isClockRunning: isClockRunning ?? this.isClockRunning,
      clockStartTime: clockStartTime ?? this.clockStartTime,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
    );
  }

  @override
  List<Object?> get props => [
    id, tournamentId, homeTeamId, awayTeamId, matchday, kickoffTime,
    status, homeGoals, awayGoals, homePenaltyGoals, awayPenaltyGoals,
    previousHomeGoals, previousAwayGoals,
    notes, createdAt, updatedAt, roundNumber, nextMatchId, homeSeed, awaySeed, homeQualifier, awayQualifier,
    homeTeam, awayTeam, isClockRunning, clockStartTime, accumulatedSeconds
  ];
}

MatchStatus _statusFromJson(String value) => MatchStatus.fromString(value);
String _statusToJson(MatchStatus status) => status.jsonValue;
