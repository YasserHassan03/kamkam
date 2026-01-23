import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_constants.dart';

part 'tournament.g.dart';

/// Tournament rules configuration stored as JSON
@JsonSerializable()
class TournamentRules extends Equatable {
  @JsonKey(fromJson: _typeFromJson, toJson: _typeToJson)
  final TournamentType type;
  
  @JsonKey(name: 'points_for_win')
  final int pointsForWin;
  
  @JsonKey(name: 'points_for_draw')
  final int pointsForDraw;
  
  @JsonKey(name: 'points_for_loss')
  final int pointsForLoss;
  
  final int rounds;
  
  @JsonKey(name: 'tiebreak_order', fromJson: _tiebreakFromJson, toJson: _tiebreakToJson)
  final List<TiebreakCriteria> tiebreakOrder;
  
  @JsonKey(name: 'match_duration_minutes')
  final int? matchDurationMinutes;
  
  @JsonKey(name: 'extra_time_allowed')
  final bool extraTimeAllowed;

  const TournamentRules({
    this.type = TournamentType.league,
    this.pointsForWin = AppConstants.defaultPointsForWin,
    this.pointsForDraw = AppConstants.defaultPointsForDraw,
    this.pointsForLoss = AppConstants.defaultPointsForLoss,
    this.rounds = AppConstants.defaultRounds,
    this.tiebreakOrder = const [
      TiebreakCriteria.points,
      TiebreakCriteria.goalDifference,
      TiebreakCriteria.goalsFor,
      TiebreakCriteria.headToHead,
    ],
    this.matchDurationMinutes,
    this.extraTimeAllowed = false,
  });

  factory TournamentRules.fromJson(Map<String, dynamic> json) =>
      _$TournamentRulesFromJson(json);

  Map<String, dynamic> toJson() => _$TournamentRulesToJson(this);

  TournamentRules copyWith({
    TournamentType? type,
    int? pointsForWin,
    int? pointsForDraw,
    int? pointsForLoss,
    int? rounds,
    List<TiebreakCriteria>? tiebreakOrder,
    int? matchDurationMinutes,
    bool? extraTimeAllowed,
  }) {
    return TournamentRules(
      type: type ?? this.type,
      pointsForWin: pointsForWin ?? this.pointsForWin,
      pointsForDraw: pointsForDraw ?? this.pointsForDraw,
      pointsForLoss: pointsForLoss ?? this.pointsForLoss,
      rounds: rounds ?? this.rounds,
      tiebreakOrder: tiebreakOrder ?? this.tiebreakOrder,
      matchDurationMinutes: matchDurationMinutes ?? this.matchDurationMinutes,
      extraTimeAllowed: extraTimeAllowed ?? this.extraTimeAllowed,
    );
  }

  @override
  List<Object?> get props => [
    type, pointsForWin, pointsForDraw, pointsForLoss,
    rounds, tiebreakOrder, matchDurationMinutes, extraTimeAllowed
  ];
}

TournamentType _typeFromJson(String? value) => 
    TournamentType.fromString(value ?? 'league');
String _typeToJson(TournamentType type) => type.jsonValue;

List<TiebreakCriteria> _tiebreakFromJson(List<dynamic>? list) => 
    list?.map((e) => TiebreakCriteria.fromString(e.toString())).toList() ?? 
    const [
      TiebreakCriteria.points,
      TiebreakCriteria.goalDifference,
      TiebreakCriteria.goalsFor,
    ];
    
List<String> _tiebreakToJson(List<TiebreakCriteria> list) => 
    list.map((e) => e.jsonValue).toList();

/// Tournament model representing a competition event
@JsonSerializable(explicitToJson: true)
class Tournament extends Equatable {
  final String id;

  @JsonKey(name: 'org_id')
  final String orgId;

  @JsonKey(name: 'owner_id')
  final String ownerId;

  @JsonKey(name: 'owner_email')
  final String? ownerEmail;

  final String name;

  @JsonKey(name: 'season_year')
  final int seasonYear;

  @JsonKey(name: 'start_date')
  final DateTime? startDate;

  @JsonKey(name: 'end_date')
  final DateTime? endDate;

  @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
  final TournamentStatus status;

  @JsonKey(name: 'visibility', fromJson: _visibilityFromJson, toJson: _visibilityToJson)
  final Visibility visibility;

  @JsonKey(name: 'format')
  final String format;

  @JsonKey(name: 'group_count')
  final int? groupCount;

  @JsonKey(name: 'qualifiers_per_group')
  final int? qualifiersPerGroup;

  @JsonKey(name: 'rules_json', fromJson: _rulesFromJson, toJson: _rulesToJson)
  final TournamentRules rules;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @JsonKey(name: 'hidden_by_admin', defaultValue: false)
  final bool hiddenByAdmin;

  const Tournament({
    required this.id,
    required this.orgId,
    required this.ownerId,
    this.ownerEmail,
    required this.name,
    required this.seasonYear,
    this.startDate,
    this.endDate,
    this.status = TournamentStatus.draft,
    this.visibility = Visibility.public,
    this.format = 'league',
    this.groupCount,
    this.qualifiersPerGroup,
    this.rules = const TournamentRules(),
    this.createdAt,
    this.updatedAt,
    this.hiddenByAdmin = false,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) =>
      _$TournamentFromJson(json);

  Map<String, dynamic> toJson() => _$TournamentToJson(this);

  Map<String, dynamic> toInsertJson() => {
    'org_id': orgId,
    'owner_id': ownerId,
    'owner_email': ownerEmail,
    'name': name,
    'season_year': seasonYear,
    'start_date': startDate?.toIso8601String().split('T').first,
    'end_date': endDate?.toIso8601String().split('T').first,
    'status': status.name,
    'visibility': visibility.name,
    'format': format,
    'group_count': groupCount,
    'qualifiers_per_group': qualifiersPerGroup,
    'rules_json': rules.toJson(),
  };

  Tournament copyWith({
    String? id,
    String? orgId,
    String? ownerId,
    String? ownerEmail,
    String? name,
    int? seasonYear,
    DateTime? startDate,
    DateTime? endDate,
    TournamentStatus? status,
    Visibility? visibility,
    String? format,
    int? groupCount,
    int? qualifiersPerGroup,
    TournamentRules? rules,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hiddenByAdmin,
  }) {
    return Tournament(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      name: name ?? this.name,
      seasonYear: seasonYear ?? this.seasonYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      format: format ?? this.format,
      groupCount: groupCount ?? this.groupCount,
      qualifiersPerGroup: qualifiersPerGroup ?? this.qualifiersPerGroup,
      rules: rules ?? this.rules,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hiddenByAdmin: hiddenByAdmin ?? this.hiddenByAdmin,
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, ownerId, ownerEmail, name, seasonYear, startDate, endDate,
    status, visibility, format, groupCount, qualifiersPerGroup, rules, createdAt, updatedAt, hiddenByAdmin
  ];
}

TournamentStatus _statusFromJson(String? value) =>
    TournamentStatus.fromString(value ?? 'draft');
String _statusToJson(TournamentStatus status) => status.name;

Visibility _visibilityFromJson(String? value) =>
    Visibility.fromString(value ?? 'public');
String _visibilityToJson(Visibility visibility) => visibility.name;

TournamentRules _rulesFromJson(dynamic json) {
  if (json == null) return const TournamentRules();
  if (json is Map<String, dynamic>) {
    return TournamentRules.fromJson(json);
  }
  return const TournamentRules();
}

Map<String, dynamic> _rulesToJson(TournamentRules rules) => rules.toJson();
