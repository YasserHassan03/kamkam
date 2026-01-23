import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/team.dart';
import '../repositories/team_repository.dart';

/// Supabase implementation of TeamRepository
class SupabaseTeamRepository implements TeamRepository {
  final SupabaseClient _client;

  SupabaseTeamRepository(this._client);

  @override
  Future<List<Team>> getTeamsByTournament(String tournamentId) async {
    final response = await _client
        .from(DbTables.teams)
        .select()
        .eq('tournament_id', tournamentId)
        .order('name');

    return (response as List).map((json) => Team.fromJson(json)).toList();
  }

  @override
  Future<Team?> getTeamById(String id) async {
    final response = await _client
        .from(DbTables.teams)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Team.fromJson(response);
  }

  @override
  Future<Team> createTeam(Team team) async {
    final response = await _client
        .from(DbTables.teams)
        .insert(team.toInsertJson())
        .select()
        .single();

    return Team.fromJson(response);
  }

  @override
  Future<Team> updateTeam(Team team) async {
    // Only update columns that exist in the database schema
    // The teams table only has: id, tournament_id, group_id, name, short_name, created_at, updated_at
    final updateData = <String, dynamic>{
      'name': team.name,
      'short_name': team.shortName,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    final response = await _client
        .from(DbTables.teams)
        .update(updateData)
        .eq('id', team.id)
        .select()
        .single();

    return Team.fromJson(response);
  }

  @override
  Future<void> deleteTeam(String id) async {
    await _client.from(DbTables.teams).delete().eq('id', id);
  }

  @override
  Future<List<Team>> createTeams(List<Team> teams) async {
    if (teams.isEmpty) return [];

    final insertData = teams.map((t) => t.toInsertJson()).toList();
    final response = await _client
        .from(DbTables.teams)
        .insert(insertData)
        .select();

    return (response as List).map((json) => Team.fromJson(json)).toList();
  }

  @override
  Future<int> getTeamCount(String tournamentId) async {
    final response = await _client
        .from(DbTables.teams)
        .select()
        .eq('tournament_id', tournamentId)
        .count(CountOption.exact);

    return response.count;
  }
}
