import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'player.g.dart';

/// Player model representing a player in a team
@JsonSerializable(explicitToJson: true)
class Player extends Equatable {
  final String id;
  
  @JsonKey(name: 'team_id')
  final String teamId;
  
  final String name;
  
  @JsonKey(name: 'player_number')
  final int? playerNumber;

  /// Optional manual goals field (nullable).
  final int? goals;
  
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Player({
    required this.id,
    required this.teamId,
    required this.name,
    this.playerNumber,
    this.goals,
    this.createdAt,
    this.updatedAt,
  });

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);

  Map<String, dynamic> toJson() => _$PlayerToJson(this);

  Map<String, dynamic> toInsertJson() => {
    'team_id': teamId,
    'name': name,
    'player_number': playerNumber,
    'goals': goals,
  };

  Player copyWith({
    String? id,
    String? teamId,
    String? name,
    int? playerNumber,
    int? goals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Player(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      playerNumber: playerNumber ?? this.playerNumber,
      goals: goals ?? this.goals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, teamId, name, playerNumber, goals, createdAt, updatedAt
  ];
}
