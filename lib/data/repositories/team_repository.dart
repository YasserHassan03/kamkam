import '../models/team.dart';

/// Repository interface for Team data operations
abstract class TeamRepository {
  /// Get all teams for a tournament
  Future<List<Team>> getTeamsByTournament(String tournamentId);

  /// Get a single team by ID
  Future<Team?> getTeamById(String id);

  /// Create a new team
  Future<Team> createTeam(Team team);

  /// Update an existing team
  Future<Team> updateTeam(Team team);

  /// Delete a team
  Future<void> deleteTeam(String id);

  /// Batch create multiple teams
  Future<List<Team>> createTeams(List<Team> teams);

  /// Get team count for a tournament
  Future<int> getTeamCount(String tournamentId);
}
