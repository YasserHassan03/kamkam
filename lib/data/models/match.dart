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
  
  final String? venue;
  
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
  
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

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
    this.venue,
    this.status = MatchStatus.scheduled,
    this.homeGoals,
    this.awayGoals,
    this.previousHomeGoals,
    this.previousAwayGoals,
    this.notes,
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
  });

  /// Whether this match has a result
  bool get hasResult => 
      status == MatchStatus.finished && homeGoals != null && awayGoals != null;

  /// Whether this is an upcoming match
  bool get isUpcoming => 
      status == MatchStatus.scheduled && 
      (kickoffTime == null || kickoffTime!.isAfter(DateTime.now()));

  /// Get the score as a string
  String get scoreDisplay => hasResult ? '$homeGoals - $awayGoals' : '- vs -';

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
    
    return Match(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      homeTeamId: json['home_team_id'] as String,
      awayTeamId: json['away_team_id'] as String,
      matchday: json['matchday'] as int?,
      kickoffTime: json['kickoff_time'] == null
          ? null
          : DateTime.parse(json['kickoff_time'] as String),
      venue: json['venue'] as String?,
      status: _statusFromJson(json['status'] as String? ?? 'scheduled'),
      homeGoals: json['home_goals'] as int?,
      awayGoals: json['away_goals'] as int?,
      previousHomeGoals: json['previous_home_goals'] as int?,
      previousAwayGoals: json['previous_away_goals'] as int?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      roundNumber: json['round_number'] as int?,
      nextMatchId: json['next_match_id'] as String?,
      homeSeed: json['home_seed'] as int?,
      awaySeed: json['away_seed'] as int?,
      homeQualifier: json['home_qualifier'] as String?,
      awayQualifier: json['away_qualifier'] as String?,
      homeTeam: homeTeamData is Map<String, dynamic>
          ? Team.fromJson(homeTeamData)
          : null,
      awayTeam: awayTeamData is Map<String, dynamic>
          ? Team.fromJson(awayTeamData)
          : null,
    );
  }

  Map<String, dynamic> toJson() => _$MatchToJson(this);

  Map<String, dynamic> toInsertJson() => {
    'tournament_id': tournamentId,
    'home_team_id': homeTeamId,
    'away_team_id': awayTeamId,
    'matchday': matchday,
    'kickoff_time': kickoffTime?.toIso8601String(),
    'venue': venue,
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
    String? venue,
    MatchStatus? status,
    int? homeGoals,
    int? awayGoals,
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
  }) {
    return Match(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      matchday: matchday ?? this.matchday,
      kickoffTime: kickoffTime ?? this.kickoffTime,
      venue: venue ?? this.venue,
      status: status ?? this.status,
      homeGoals: homeGoals ?? this.homeGoals,
      awayGoals: awayGoals ?? this.awayGoals,
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
    );
  }

  @override
  List<Object?> get props => [
    id, tournamentId, homeTeamId, awayTeamId, matchday, kickoffTime,
    venue, status, homeGoals, awayGoals, previousHomeGoals, previousAwayGoals,
    notes, createdAt, updatedAt, roundNumber, nextMatchId, homeSeed, awaySeed, homeQualifier, awayQualifier,
    homeTeam, awayTeam
  ];
}

MatchStatus _statusFromJson(String value) => MatchStatus.fromString(value);
String _statusToJson(MatchStatus status) => status.jsonValue;
