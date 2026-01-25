import '../models/player.dart';
import '../models/golden_boot_entry.dart';

/// Repository interface for Player data operations
abstract class PlayerRepository {
  /// Get all players for a team
  Future<List<Player>> getPlayersByTeam(String teamId);

  /// Get a single player by ID
  Future<Player?> getPlayerById(String id);

  /// Create a new player
  Future<Player> createPlayer(Player player);

  /// Update an existing player
  Future<Player> updatePlayer(Player player);

  /// Delete a player
  Future<void> deletePlayer(String id);

  /// Batch create multiple players
  Future<List<Player>> createPlayers(List<Player> players);

  /// Get player count for a team
  Future<int> getPlayerCount(String teamId);

  /// Get Golden Boot table (players + goals) for a tournament
  Future<List<GoldenBootEntry>> getGoldenBoot(String tournamentId);
}
