// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Team _$TeamFromJson(Map<String, dynamic> json) => Team(
  id: json['id'] as String,
  tournamentId: json['tournament_id'] as String,
  name: json['name'] as String,
  shortName: json['short_name'] as String?,
  logoUrl: json['logo_url'] as String?,
  primaryColor: json['primary_color'] as String?,
  secondaryColor: json['secondary_color'] as String?,
  groupNumber: (json['group_number'] as num?)?.toInt(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$TeamToJson(Team instance) => <String, dynamic>{
  'id': instance.id,
  'tournament_id': instance.tournamentId,
  'name': instance.name,
  'short_name': instance.shortName,
  'logo_url': instance.logoUrl,
  'primary_color': instance.primaryColor,
  'secondary_color': instance.secondaryColor,
  'group_number': instance.groupNumber,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
