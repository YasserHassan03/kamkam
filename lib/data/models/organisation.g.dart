// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organisation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Organisation _$OrganisationFromJson(Map<String, dynamic> json) => Organisation(
  id: json['id'] as String,
  name: json['name'] as String,
  ownerId: json['owner_id'] as String,
  ownerEmail: json['owner_email'] as String,
  description: json['description'] as String?,
  logoUrl: json['logo_url'] as String?,
  visibility: json['visibility'] == null
      ? Visibility.public
      : _visibilityFromJson(json['visibility'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$OrganisationToJson(Organisation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'owner_id': instance.ownerId,
      'owner_email': instance.ownerEmail,
      'description': instance.description,
      'logo_url': instance.logoUrl,
      'visibility': _visibilityToJson(instance.visibility),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
