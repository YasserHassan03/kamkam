// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Match _$MatchFromJson(Map<String, dynamic> json) => Match(
  id: json['id'] as String,
  tournamentId: json['tournament_id'] as String,
  homeTeamId: json['home_team_id'] as String,
  awayTeamId: json['away_team_id'] as String,
  matchday: (json['matchday'] as num?)?.toInt(),
  kickoffTime: json['kickoff_time'] == null
      ? null
      : DateTime.parse(json['kickoff_time'] as String),
  status: json['status'] == null
      ? MatchStatus.scheduled
      : _statusFromJson(json['status'] as String),
  homeGoals: (json['home_goals'] as num?)?.toInt(),
  awayGoals: (json['away_goals'] as num?)?.toInt(),
  previousHomeGoals: (json['previous_home_goals'] as num?)?.toInt(),
  previousAwayGoals: (json['previous_away_goals'] as num?)?.toInt(),
  notes: json['notes'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  roundNumber: (json['round_number'] as num?)?.toInt(),
  nextMatchId: json['next_match_id'] as String?,
  homeSeed: (json['home_seed'] as num?)?.toInt(),
  awaySeed: (json['away_seed'] as num?)?.toInt(),
  homeQualifier: json['home_qualifier'] as String?,
  awayQualifier: json['away_qualifier'] as String?,
  homeTeam: json['home_team'] == null
      ? null
      : Team.fromJson(json['home_team'] as Map<String, dynamic>),
  awayTeam: json['away_team'] == null
      ? null
      : Team.fromJson(json['away_team'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MatchToJson(Match instance) => <String, dynamic>{
  'id': instance.id,
  'tournament_id': instance.tournamentId,
  'home_team_id': instance.homeTeamId,
  'away_team_id': instance.awayTeamId,
  'matchday': instance.matchday,
  'kickoff_time': instance.kickoffTime?.toIso8601String(),
  'status': _statusToJson(instance.status),
  'home_goals': instance.homeGoals,
  'away_goals': instance.awayGoals,
  'previous_home_goals': instance.previousHomeGoals,
  'previous_away_goals': instance.previousAwayGoals,
  'notes': instance.notes,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'round_number': instance.roundNumber,
  'next_match_id': instance.nextMatchId,
  'home_seed': instance.homeSeed,
  'away_seed': instance.awaySeed,
  'home_qualifier': instance.homeQualifier,
  'away_qualifier': instance.awayQualifier,
  'home_team': instance.homeTeam?.toJson(),
  'away_team': instance.awayTeam?.toJson(),
};
