import '../models/tournament.dart';

/// Repository interface for Tournament data operations
abstract class TournamentRepository {
  /// Get all public tournaments
  Future<List<Tournament>> getPublicTournaments();

  /// Get tournaments for a specific organisation
  Future<List<Tournament>> getTournamentsByOrganisation(String orgId);

  /// Get a single tournament by ID
  Future<Tournament?> getTournamentById(String id);

  /// Create a new tournament
  Future<Tournament> createTournament(Tournament tournament);

  /// Update an existing tournament
  Future<Tournament> updateTournament(Tournament tournament);

  /// Delete a tournament
  Future<void> deleteTournament(String id);

  /// Get active tournaments (status = active)
  Future<List<Tournament>> getActiveTournaments();

  /// Search tournaments by name
  Future<List<Tournament>> searchTournaments(String query);

  /// Get tournaments created by a specific user
  Future<List<Tournament>> getUserTournaments(String userId);

  /// Generate teams for a tournament
  Future<void> generateTeams(String tournamentId, int teamCount);

  /// Generate fixtures for a tournament
  Future<Map<String, dynamic>> generateFixtures(String tournamentId);

  /// Toggle hide/show tournament for admin (overrides organiser visibility)
  Future<Tournament> toggleTournamentVisibility(String tournamentId, bool hidden);

  /// Get all tournaments (admin only - bypasses visibility filters)
  Future<List<Tournament>> getAllTournaments();
}
