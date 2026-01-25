// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Standing _$StandingFromJson(Map<String, dynamic> json) => Standing(
  id: json['id'] as String,
  tournamentId: json['tournament_id'] as String,
  groupId: json['group_id'] as String?,
  teamId: json['team_id'] as String,
  played: (json['played'] as num?)?.toInt() ?? 0,
  won: (json['won'] as num?)?.toInt() ?? 0,
  drawn: (json['drawn'] as num?)?.toInt() ?? 0,
  lost: (json['lost'] as num?)?.toInt() ?? 0,
  goalsFor: (json['goals_for'] as num?)?.toInt() ?? 0,
  goalsAgainst: (json['goals_against'] as num?)?.toInt() ?? 0,
  goalDifference: (json['goal_difference'] as num?)?.toInt() ?? 0,
  points: (json['points'] as num?)?.toInt() ?? 0,
  form: json['form'] as String?,
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  team: json['team'] == null
      ? null
      : Team.fromJson(json['team'] as Map<String, dynamic>),
);

Map<String, dynamic> _$StandingToJson(Standing instance) => <String, dynamic>{
  'id': instance.id,
  'tournament_id': instance.tournamentId,
  'group_id': instance.groupId,
  'team_id': instance.teamId,
  'played': instance.played,
  'won': instance.won,
  'drawn': instance.drawn,
  'lost': instance.lost,
  'goals_for': instance.goalsFor,
  'goals_against': instance.goalsAgainst,
  'goal_difference': instance.goalDifference,
  'points': instance.points,
  'form': instance.form,
  'updated_at': instance.updatedAt?.toIso8601String(),
  'team': ?instance.team?.toJson(),
};
