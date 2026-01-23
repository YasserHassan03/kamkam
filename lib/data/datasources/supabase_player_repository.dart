import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/player.dart';
import '../repositories/player_repository.dart';

/// Supabase implementation of PlayerRepository
class SupabasePlayerRepository implements PlayerRepository {
  final SupabaseClient _client;

  SupabasePlayerRepository(this._client);

  @override
  Future<List<Player>> getPlayersByTeam(String teamId) async {
    final response = await _client
        .from(DbTables.players)
        .select()
        .eq('team_id', teamId)
        .order('name');

    return (response as List).map((json) => Player.fromJson(json)).toList();
  }

  @override
  Future<Player?> getPlayerById(String id) async {
    final response = await _client
        .from(DbTables.players)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Player.fromJson(response);
  }

  @override
  Future<Player> createPlayer(Player player) async {
    final response = await _client
        .from(DbTables.players)
        .insert(player.toInsertJson())
        .select()
        .single();

    return Player.fromJson(response);
  }

  @override
  Future<Player> updatePlayer(Player player) async {
    // Only update columns that exist in the database schema
    // The players table only has: id, team_id, name, contact_info, created_at, updated_at
    final response = await _client
        .from(DbTables.players)
        .update({
          'name': player.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', player.id)
        .select()
        .single();

    return Player.fromJson(response);
  }

  @override
  Future<void> deletePlayer(String id) async {
    await _client.from(DbTables.players).delete().eq('id', id);
  }

  @override
  Future<List<Player>> createPlayers(List<Player> players) async {
    if (players.isEmpty) return [];

    final insertData = players.map((p) => p.toInsertJson()).toList();
    final response = await _client
        .from(DbTables.players)
        .insert(insertData)
        .select();

    return (response as List).map((json) => Player.fromJson(json)).toList();
  }

  @override
  Future<int> getPlayerCount(String teamId) async {
    final response = await _client
        .from(DbTables.players)
        .select()
        .eq('team_id', teamId)
        .count(CountOption.exact);

    return response.count;
  }
}
