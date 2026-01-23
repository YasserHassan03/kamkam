import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../core/constants/enums.dart';

part 'player.g.dart';

/// Player model representing a player in a team
@JsonSerializable(explicitToJson: true)
class Player extends Equatable {
  final String id;
  
  @JsonKey(name: 'team_id')
  final String teamId;
  
  final String name;
  
  @JsonKey(name: 'jersey_number')
  final int? jerseyNumber;
  
  @JsonKey(fromJson: _positionFromJson, toJson: _positionToJson)
  final PlayerPosition? position;
  
  @JsonKey(name: 'is_captain')
  final bool isCaptain;
  
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Player({
    required this.id,
    required this.teamId,
    required this.name,
    this.jerseyNumber,
    this.position,
    this.isCaptain = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);

  Map<String, dynamic> toJson() => _$PlayerToJson(this);

  Map<String, dynamic> toInsertJson() => {
    'team_id': teamId,
    'name': name,
    'jersey_number': jerseyNumber,
    'position': position?.name,
    'is_captain': isCaptain,
  };

  Player copyWith({
    String? id,
    String? teamId,
    String? name,
    int? jerseyNumber,
    PlayerPosition? position,
    bool? isCaptain,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Player(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      position: position ?? this.position,
      isCaptain: isCaptain ?? this.isCaptain,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, teamId, name, jerseyNumber, position, isCaptain, createdAt, updatedAt
  ];
}

PlayerPosition? _positionFromJson(String? value) => 
    PlayerPosition.fromString(value);
String? _positionToJson(PlayerPosition? position) => position?.name;
