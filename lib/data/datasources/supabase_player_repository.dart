import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/golden_boot_entry.dart';
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
    final response = await _client
        .from(DbTables.players)
        .update({
          'name': player.name,
          'player_number': player.playerNumber,
          'goals': player.goals,
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

  @override
  Future<List<GoldenBootEntry>> getGoldenBoot(String tournamentId) async {
    final response = await _client
        .from(DbTables.players)
        .select('''
          id,
          name,
          team_id,
          player_number,
          goals,
          team:teams!inner(
            id,
            name,
            tournament_id
          )
        ''')
        .eq('team.tournament_id', tournamentId)
        .order('goals', ascending: false, nullsFirst: false)
        .order('name');

    final entries = (response as List).map((row) {
      final map = row as Map<String, dynamic>;
      final team = map['team'] as Map<String, dynamic>?;

      return GoldenBootEntry(
        playerId: map['id'] as String,
        playerName: (map['name'] as String?) ?? '',
        teamId: map['team_id'] as String,
        teamName: (team?['name'] as String?) ?? 'Unknown Team',
        playerNumber: (map['player_number'] as num?)?.toInt(),
        goals: (map['goals'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // Defensive deterministic sorting (goals desc, then name asc, then id asc)
    entries.sort((a, b) {
      final goalsCmp = b.goals.compareTo(a.goals);
      if (goalsCmp != 0) return goalsCmp;
      final nameCmp = a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase());
      if (nameCmp != 0) return nameCmp;
      return a.playerId.compareTo(b.playerId);
    });

    return entries;
  }
}
