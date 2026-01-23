import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../core/constants/enums.dart';
import 'team.dart';

part 'standing.g.dart';

/// Standing model representing a team's position in the league table
@JsonSerializable(explicitToJson: true)
class Standing extends Equatable {
  final String id;
  
  @JsonKey(name: 'tournament_id')
  final String tournamentId;
  
  @JsonKey(name: 'team_id')
  final String teamId;
  
  final int played;
  final int won;
  final int drawn;
  final int lost;
  
  @JsonKey(name: 'goals_for')
  final int goalsFor;
  
  @JsonKey(name: 'goals_against')
  final int goalsAgainst;
  
  @JsonKey(name: 'goal_difference')
  final int goalDifference;
  
  final int points;
  
  final String? form;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Optional joined data
  @JsonKey(name: 'team', includeIfNull: false)
  final Team? team;

  // Calculated position (set after sorting)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? position;

  const Standing({
    required this.id,
    required this.tournamentId,
    required this.teamId,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.goalDifference = 0,
    this.points = 0,
    this.form,
    this.updatedAt,
    this.team,
    this.position,
  });

  /// Get form as list of results
  List<MatchResult> get formResults {
    if (form == null || form!.isEmpty) return [];
    return form!.split('').map((char) {
      switch (char.toUpperCase()) {
        case 'W':
          return MatchResult.win;
        case 'D':
          return MatchResult.draw;
        case 'L':
          return MatchResult.loss;
        default:
          return MatchResult.draw;
      }
    }).toList();
  }

  factory Standing.fromJson(Map<String, dynamic> json) {
    // Handle nested team data from joins
    final teamData = json['team'];
    
    return Standing(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      teamId: json['team_id'] as String,
      played: json['played'] as int? ?? 0,
      won: json['won'] as int? ?? 0,
      drawn: json['drawn'] as int? ?? 0,
      lost: json['lost'] as int? ?? 0,
      goalsFor: json['goals_for'] as int? ?? 0,
      goalsAgainst: json['goals_against'] as int? ?? 0,
      goalDifference: json['goal_difference'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      form: json['form'] as String?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      team: teamData is Map<String, dynamic>
          ? Team.fromJson(teamData)
          : null,
    );
  }

  Map<String, dynamic> toJson() => _$StandingToJson(this);

  Standing copyWith({
    String? id,
    String? tournamentId,
    String? teamId,
    int? played,
    int? won,
    int? drawn,
    int? lost,
    int? goalsFor,
    int? goalsAgainst,
    int? goalDifference,
    int? points,
    String? form,
    DateTime? updatedAt,
    Team? team,
    int? position,
  }) {
    return Standing(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      teamId: teamId ?? this.teamId,
      played: played ?? this.played,
      won: won ?? this.won,
      drawn: drawn ?? this.drawn,
      lost: lost ?? this.lost,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      goalDifference: goalDifference ?? this.goalDifference,
      points: points ?? this.points,
      form: form ?? this.form,
      updatedAt: updatedAt ?? this.updatedAt,
      team: team ?? this.team,
      position: position ?? this.position,
    );
  }

  @override
  List<Object?> get props => [
    id, tournamentId, teamId, played, won, drawn, lost,
    goalsFor, goalsAgainst, goalDifference, points, form, updatedAt, team
  ];
}

/// Utility class for sorting standings
class StandingSorter {
  /// Sort standings by default league order (points, GD, GF)
  static List<Standing> sortStandings(List<Standing> standings) {
    final sorted = List<Standing>.from(standings);
    sorted.sort((a, b) {
      // First by points
      final pointsDiff = b.points.compareTo(a.points);
      if (pointsDiff != 0) return pointsDiff;
      
      // Then by goal difference
      final gdDiff = b.goalDifference.compareTo(a.goalDifference);
      if (gdDiff != 0) return gdDiff;
      
      // Then by goals scored
      final gfDiff = b.goalsFor.compareTo(a.goalsFor);
      if (gfDiff != 0) return gfDiff;
      
      // Then alphabetically by team name
      if (a.team != null && b.team != null) {
        return a.team!.name.compareTo(b.team!.name);
      }
      
      return 0;
    });
    
    // Add positions
    return sorted.asMap().entries.map((entry) {
      return entry.value.copyWith(position: entry.key + 1);
    }).toList();
  }
}
