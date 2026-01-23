import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/standing.dart';
import '../repositories/standing_repository.dart';

/// Supabase implementation of StandingRepository
class SupabaseStandingRepository implements StandingRepository {
  final SupabaseClient _client;

  SupabaseStandingRepository(this._client);

  @override
  Future<List<Standing>> getStandingsByTournament(String tournamentId) async {
    final response = await _client
        .from(DbTables.standings)
        .select()
        .eq('tournament_id', tournamentId)
        .order('points', ascending: false)
        .order('goal_difference', ascending: false)
        .order('goals_for', ascending: false);

    final standings = (response as List)
        .map((json) => Standing.fromJson(json))
        .toList();

    return StandingSorter.sortStandings(standings);
  }

  @override
  Future<List<Standing>> getStandingsWithTeams(String tournamentId) async {
    final response = await _client
        .from(DbTables.standings)
        .select('''
          *,
          team:teams(*)
        ''')
        .eq('tournament_id', tournamentId);

    final standings = (response as List)
        .map((json) => Standing.fromJson(json))
        .toList();

    return StandingSorter.sortStandings(standings);
  }

  @override
  Future<Standing?> getStandingByTeam(String tournamentId, String teamId) async {
    final response = await _client
        .from(DbTables.standings)
        .select('''
          *,
          team:teams(*)
        ''')
        .eq('tournament_id', tournamentId)
        .eq('team_id', teamId)
        .maybeSingle();

    if (response == null) return null;
    return Standing.fromJson(response);
  }

  @override
  Future<Standing> initializeTeamStanding(String tournamentId, String teamId) async {
    final response = await _client
        .from(DbTables.standings)
        .insert({
          'tournament_id': tournamentId,
          'team_id': teamId,
        })
        .select()
        .single();

    return Standing.fromJson(response);
  }

  @override
  Future<void> resetStandings(String tournamentId) async {
    await _client
        .from(DbTables.standings)
        .update({
          'played': 0,
          'won': 0,
          'drawn': 0,
          'lost': 0,
          'goals_for': 0,
          'goals_against': 0,
          'points': 0,
          'form': null,
        })
        .eq('tournament_id', tournamentId);
  }
}
