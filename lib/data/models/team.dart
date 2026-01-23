import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'team.g.dart';

/// Team model representing a participating team in a tournament
@JsonSerializable(explicitToJson: true)
class Team extends Equatable {
  final String id;

  @JsonKey(name: 'tournament_id')
  final String tournamentId;

  final String name;

  @JsonKey(name: 'short_name')
  final String? shortName;

  @JsonKey(name: 'logo_url')
  final String? logoUrl;

  @JsonKey(name: 'primary_color')
  final String? primaryColor;

  @JsonKey(name: 'secondary_color')
  final String? secondaryColor;

  @JsonKey(name: 'group_number')
  final int? groupNumber;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Team({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.shortName,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.groupNumber,
    this.createdAt,
    this.updatedAt,
  });

  /// Display name - uses short name if available, otherwise truncates
  String get displayName => shortName ?? 
      (name.length > 10 ? '${name.substring(0, 10)}...' : name);

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);

  Map<String, dynamic> toJson() => _$TeamToJson(this);

  Map<String, dynamic> toInsertJson() => {
    'tournament_id': tournamentId,
    'name': name,
    'short_name': shortName,
    'logo_url': logoUrl,
    'primary_color': primaryColor,
    'secondary_color': secondaryColor,
    'group_number': groupNumber,
  };

  Team copyWith({
    String? id,
    String? tournamentId,
    String? name,
    String? shortName,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    int? groupNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      groupNumber: groupNumber ?? this.groupNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, tournamentId, name, shortName, logoUrl,
    primaryColor, secondaryColor, groupNumber, createdAt, updatedAt
  ];
}
