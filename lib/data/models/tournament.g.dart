// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tournament.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TournamentRules _$TournamentRulesFromJson(Map<String, dynamic> json) =>
    TournamentRules(
      type: json['type'] == null
          ? TournamentType.league
          : _typeFromJson(json['type']?.toString()),
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

Tournament _$TournamentFromJson(Map<String, dynamic> json) {
  // Safely extract and convert all fields with comprehensive null handling
  String safeString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    return value.toString();
  }
  
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
  
  return Tournament(
    id: safeString(json['id'], ''),
    orgId: safeString(json['org_id'], ''),
    ownerId: safeString(json['owner_id'], ''),
    ownerEmail: json['owner_email']?.toString(),
    name: safeString(json['name'], ''),
    seasonYear: (json['season_year'] as num?)?.toInt() ?? DateTime.now().year,
    startDate: safeDateTime(json['start_date']),
    endDate: safeDateTime(json['end_date']),
    status: json['status'] == null
        ? TournamentStatus.draft
        : _statusFromJson(safeString(json['status'], 'draft')),
    visibility: json['visibility'] == null
        ? Visibility.public
        : _visibilityFromJson(safeString(json['visibility'], 'public')),
    format: safeString(json['format'], 'league'),
    groupCount: (json['group_count'] as num?)?.toInt(),
    qualifiersPerGroup: (json['qualifiers_per_group'] as num?)?.toInt(),
    rules: json['rules_json'] == null
        ? const TournamentRules()
        : _rulesFromJson(json['rules_json']),
    createdAt: safeDateTime(json['created_at']),
    updatedAt: safeDateTime(json['updated_at']),
    hiddenByAdmin: json['hidden_by_admin'] as bool? ?? false,
    venue: json['venue']?.toString(),
  );
}

Map<String, dynamic> _$TournamentToJson(Tournament instance) =>
    <String, dynamic>{
      'id': instance.id,
      'org_id': instance.orgId,
      'owner_id': instance.ownerId,
      'owner_email': instance.ownerEmail,
      'name': instance.name,
      'season_year': instance.seasonYear,
      'start_date': instance.startDate?.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'status': _statusToJson(instance.status),
      'visibility': _visibilityToJson(instance.visibility),
      'format': instance.format,
      'group_count': instance.groupCount,
      'qualifiers_per_group': instance.qualifiersPerGroup,
      'rules_json': _rulesToJson(instance.rules),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'hidden_by_admin': instance.hiddenByAdmin,
      'venue': instance.venue,
    };
