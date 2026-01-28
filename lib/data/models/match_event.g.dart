// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchEvent _$MatchEventFromJson(Map<String, dynamic> json) => MatchEvent(
  id: json['id'] as String,
  matchId: json['match_id'] as String,
  teamId: json['team_id'] as String?,
  eventType: $enumDecode(_$MatchEventTypeEnumMap, json['event_type']),
  playerId: json['player_id'] as String?,
  playerName: json['player_name'] as String?,
  minute: (json['minute'] as num?)?.toInt(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MatchEventToJson(MatchEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'match_id': instance.matchId,
      'team_id': instance.teamId,
      'event_type': _$MatchEventTypeEnumMap[instance.eventType]!,
      'player_id': instance.playerId,
      'player_name': instance.playerName,
      'minute': instance.minute,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$MatchEventTypeEnumMap = {
  MatchEventType.goal: 'goal',
  MatchEventType.ownGoal: 'own_goal',
  MatchEventType.penalty: 'penalty',
};
