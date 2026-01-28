import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'match_event.g.dart';

/// Types of match events
enum MatchEventType {
  @JsonValue('goal')
  goal('Goal'),
  @JsonValue('own_goal')
  ownGoal('Own Goal'),
  @JsonValue('penalty')
  penalty('Penalty');

  final String displayName;
  const MatchEventType(this.displayName);
}

/// Represents a goal or event during a match
@JsonSerializable()
class MatchEvent extends Equatable {
  final String id;
  
  @JsonKey(name: 'match_id')
  final String matchId;
  
  @JsonKey(name: 'team_id')
  final String? teamId;
  
  @JsonKey(name: 'event_type')
  final MatchEventType eventType;
  
  @JsonKey(name: 'player_id')
  final String? playerId;
  
  @JsonKey(name: 'player_name')
  final String? playerName;
  
  final int? minute;
  
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const MatchEvent({
    required this.id,
    required this.matchId,
    this.teamId,
    required this.eventType,
    this.playerId,
    this.playerName,
    this.minute,
    this.createdAt,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) =>
      _$MatchEventFromJson(json);

  Map<String, dynamic> toJson() => _$MatchEventToJson(this);

  /// Display string for the event (e.g., "⚽ Player Name 45'")
  String get displayText {
    final icon = switch (eventType) {
      MatchEventType.goal => '⚽',
      MatchEventType.ownGoal => '🔴',
      MatchEventType.penalty => '🎯',
    };
    final name = playerName ?? 'Unknown';
    final min = minute != null ? "$minute'" : '';
    return '$icon $name $min';
  }

  @override
  List<Object?> get props => [id, matchId, teamId, eventType, playerId, playerName, minute, createdAt];
}
