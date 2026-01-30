import '../models/match.dart';

/// Result of fixture generation
class FixtureGenerationResult {
  final bool success;
  final int matchesCreated;
  final int rounds;
  final int matchdays;
  final String? error;

  const FixtureGenerationResult({
    required this.success,
    this.matchesCreated = 0,
    this.rounds = 0,
    this.matchdays = 0,
    this.error,
  });

  factory FixtureGenerationResult.fromJson(Map<String, dynamic> json) {
    return FixtureGenerationResult(
      success: json['success'] as bool? ?? false,
      matchesCreated: json['matches_created'] as int? ?? 0,
      rounds: json['rounds'] as int? ?? 0,
      matchdays: json['matchdays'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

/// Result of match result update
class MatchResultUpdateResult {
  final bool success;
  final String matchId;
  final int homeGoals;
  final int awayGoals;
  final int? homePenaltyGoals;
  final int? awayPenaltyGoals;
  final String? error;

  const MatchResultUpdateResult({
    required this.success,
    required this.matchId,
    required this.homeGoals,
    required this.awayGoals,
    this.homePenaltyGoals,
    this.awayPenaltyGoals,
    this.error,
  });

  factory MatchResultUpdateResult.fromJson(Map<String, dynamic> json) {
    return MatchResultUpdateResult(
      success: json['success'] as bool? ?? false,
      matchId: json['match_id'] as String? ?? '',
      homeGoals: json['home_goals'] as int? ?? 0,
      awayGoals: json['away_goals'] as int? ?? 0,
      homePenaltyGoals: json['home_penalty_goals'] as int?,
      awayPenaltyGoals: json['away_penalty_goals'] as int?,
      error: json['error'] as String?,
    );
  }
}

/// Result of knockout stage generation (group_knockout -> knockout stage)
class KnockoutStageGenerationResult {
  final bool success;
  final int matchesCreated;
  final int rounds;
  final String? error;

  const KnockoutStageGenerationResult({
    required this.success,
    this.matchesCreated = 0,
    this.rounds = 0,
    this.error,
  });

  factory KnockoutStageGenerationResult.fromJson(Map<String, dynamic> json) {
    return KnockoutStageGenerationResult(
      success: json['success'] as bool? ?? false,
      matchesCreated: json['matches_created'] as int? ?? 0,
      rounds: json['rounds'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

/// Repository interface for Match data operations
abstract class MatchRepository {
  /// Get all matches for a tournament
  Future<List<Match>> getMatchesByTournament(String tournamentId);

  /// Get matches for a tournament with team data joined
  Future<List<Match>> getMatchesWithTeams(String tournamentId);

  /// Get upcoming matches (scheduled, not yet played)
  Future<List<Match>> getUpcomingMatches(String tournamentId, {int limit = 10});

  /// Get recent results (finished matches)
  Future<List<Match>> getRecentResults(String tournamentId, {int limit = 10});

  /// Get matches by matchday
  Future<List<Match>> getMatchesByMatchday(String tournamentId, int matchday);

  /// Get a single match by ID
  Future<Match?> getMatchById(String id);

  /// Get a match by ID with team data
  Future<Match?> getMatchWithTeams(String id);

  /// Create a new match (manual fixture)
  Future<Match> createMatch(Match match);

  /// Update match details (not result)
  Future<Match> updateMatch(Match match);

  /// Delete a match
  Future<void> deleteMatch(String id);

  /// Update match result using the RPC function (transactional with standings)
  Future<MatchResultUpdateResult> updateMatchResult({
    required String matchId,
    required int homeGoals,
    required int awayGoals,
    int? homePenaltyGoals,
    int? awayPenaltyGoals,
  });

  /// Generate round-robin fixtures using the RPC function
  Future<FixtureGenerationResult> generateRoundRobinFixtures({
    required String tournamentId,
    DateTime? startDate,
    int daysBetweenMatchdays = 7,
  });

  /// Generate format-aware fixtures via RPC
  Future<Map<String, dynamic>> generateFormatAwareFixtures({
    required String tournamentId,
    DateTime? startDate,
    int daysBetweenMatchdays = 7,
  });

  /// Generate knockout stage for a group_knockout tournament (after group stage completion)
  Future<KnockoutStageGenerationResult> generateGroupKnockoutKnockouts({
    required String tournamentId,
  });

  /// Delete all fixtures for a tournament
  Future<void> deleteAllFixtures(String tournamentId);

  /// Get all live matches for a tournament
  Future<List<Match>> getLiveMatches(String tournamentId);

  /// Get all matches for a specific team
  Future<List<Match>> getMatchesByTeam(String teamId);

  /// Toggle the match clock (start/pause/resume)
  Future<Match> toggleMatchClock(Match match, bool start);
}
