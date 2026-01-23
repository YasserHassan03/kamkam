// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tournament.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TournamentRules _$TournamentRulesFromJson(Map<String, dynamic> json) =>
    TournamentRules(
      type: json['type'] == null
          ? TournamentType.league
          : _typeFromJson(json['type'] as String?),
      pointsForWin:
          (json['points_for_win'] as num?)?.toInt() ??
          AppConstants.defaultPointsForWin,
      pointsForDraw:
          (json['points_for_draw'] as num?)?.toInt() ??
          AppConstants.defaultPointsForDraw,
      pointsForLoss:
          (json['points_for_loss'] as num?)?.toInt() ??
          AppConstants.defaultPointsForLoss,
      rounds: (json['rounds'] as num?)?.toInt() ?? AppConstants.defaultRounds,
      tiebreakOrder: json['tiebreak_order'] == null
          ? const [
              TiebreakCriteria.points,
              TiebreakCriteria.goalDifference,
              TiebreakCriteria.goalsFor,
              TiebreakCriteria.headToHead,
            ]
          : _tiebreakFromJson(json['tiebreak_order'] as List?),
      matchDurationMinutes: (json['match_duration_minutes'] as num?)?.toInt(),
      extraTimeAllowed: json['extra_time_allowed'] as bool? ?? false,
    );

Map<String, dynamic> _$TournamentRulesToJson(TournamentRules instance) =>
    <String, dynamic>{
      'type': _typeToJson(instance.type),
      'points_for_win': instance.pointsForWin,
      'points_for_draw': instance.pointsForDraw,
      'points_for_loss': instance.pointsForLoss,
      'rounds': instance.rounds,
      'tiebreak_order': _tiebreakToJson(instance.tiebreakOrder),
      'match_duration_minutes': instance.matchDurationMinutes,
      'extra_time_allowed': instance.extraTimeAllowed,
    };

Tournament _$TournamentFromJson(Map<String, dynamic> json) => Tournament(
  id: json['id'] as String,
  name: json['name'] as String,
  seasonYear: (json['season_year'] as num).toInt(),
  ownerId: json['owner_id'] as String?,
  startDate: json['start_date'] == null
      ? null
      : DateTime.parse(json['start_date'] as String),
  endDate: json['end_date'] == null
      ? null
      : DateTime.parse(json['end_date'] as String),
  status: json['status'] == null
      ? TournamentStatus.draft
      : _statusFromJson(json['status'] as String),
  format: json['format'] as String? ?? 'league',
  groupCount: (json['group_count'] as num?)?.toInt(),
  qualifiersPerGroup: (json['qualifiers_per_group'] as num?)?.toInt(),
  rules: json['rules_json'] == null
      ? const TournamentRules()
      : _rulesFromJson(json['rules_json']),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$TournamentToJson(Tournament instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner_id': instance.ownerId,
      'name': instance.name,
      'season_year': instance.seasonYear,
      'start_date': instance.startDate?.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'status': _statusToJson(instance.status),
      'format': instance.format,
      'group_count': instance.groupCount,
      'qualifiers_per_group': instance.qualifiersPerGroup,
      'rules_json': _rulesToJson(instance.rules),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
