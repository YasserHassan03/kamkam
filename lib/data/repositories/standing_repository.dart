import '../models/standing.dart';

/// Repository interface for Standing data operations
abstract class StandingRepository {
  /// Get standings for a tournament (sorted by position)
  Future<List<Standing>> getStandingsByTournament(String tournamentId);

  /// Get standings with team data joined
  Future<List<Standing>> getStandingsWithTeams(String tournamentId);

  /// Get standing for a specific team
  Future<Standing?> getStandingByTeam(String tournamentId, String teamId);

  /// Initialize standings for a new team (usually handled by DB trigger)
  Future<Standing> initializeTeamStanding(String tournamentId, String teamId);

  /// Reset all standings for a tournament
  Future<void> resetStandings(String tournamentId);
}
