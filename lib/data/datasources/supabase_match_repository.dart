import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/match.dart';
import '../repositories/match_repository.dart';

/// Supabase implementation of MatchRepository
class SupabaseMatchRepository implements MatchRepository {
  final SupabaseClient _client;

  SupabaseMatchRepository(this._client);

  @override
  Future<List<Match>> getMatchesByTournament(String tournamentId) async {
    final response = await _client
        .from(DbTables.matches)
        .select()
        .eq('tournament_id', tournamentId)
        .order('matchday')
        .order('kickoff_time');

    return (response as List).map((json) => Match.fromJson(json)).toList();
  }

  @override
  Future<List<Match>> getMatchesWithTeams(String tournamentId) async {
    final response = await _client
        .from(DbTables.matches)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .eq('tournament_id', tournamentId)
        .order('matchday')
        .order('kickoff_time');

    return (response as List).map((json) => Match.fromJson(json)).toList();
  }

  @override
  Future<List<Match>> getUpcomingMatches(String tournamentId, {int limit = 10}) async {
    final response = await _client
        .from(DbTables.matches)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .eq('tournament_id', tournamentId)
        .eq('status', 'scheduled')
        .order('kickoff_time')
        .limit(limit);

    return (response as List).map((json) => Match.fromJson(json)).toList();
  }

  @override
  Future<List<Match>> getRecentResults(String tournamentId, {int limit = 10}) async {
    final response = await _client
        .from(DbTables.matches)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .eq('tournament_id', tournamentId)
        .eq('status', 'finished')
        .order('updated_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Match.fromJson(json)).toList();
  }

  @override
  Future<List<Match>> getMatchesByMatchday(String tournamentId, int matchday) async {
    final response = await _client
        .from(DbTables.matches)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .eq('tournament_id', tournamentId)
        .eq('matchday', matchday)
        .order('kickoff_time');

    return (response as List).map((json) => Match.fromJson(json)).toList();
  }

  @override
  Future<Match?> getMatchById(String id) async {
    final response = await _client
        .from(DbTables.matches)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Match.fromJson(response);
  }

  @override
  Future<Match?> getMatchWithTeams(String id) async {
    final response = await _client
        .from(DbTables.matches)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Match.fromJson(response);
  }

  @override
  Future<Match> createMatch(Match match) async {
    final response = await _client
        .from(DbTables.matches)
        .insert(match.toInsertJson())
        .select()
        .single();

    return Match.fromJson(response);
  }

  @override
  Future<Match> updateMatch(Match match) async {
    final response = await _client
        .from(DbTables.matches)
        .update({
          'home_team_id': match.homeTeamId,
          'away_team_id': match.awayTeamId,
          'matchday': match.matchday,
          'kickoff_time': match.kickoffTime?.toIso8601String(),
          'status': match.status.jsonValue,
          'notes': match.notes,
        })
        .eq('id', match.id)
        .select()
        .single();

    return Match.fromJson(response);
  }

  @override
  Future<void> deleteMatch(String id) async {
    await _client.from(DbTables.matches).delete().eq('id', id);
  }

  @override
  Future<MatchResultUpdateResult> updateMatchResult({
    required String matchId,
    required int homeGoals,
    required int awayGoals,
  }) async {
    try {
      final response = await _client.rpc(
        RpcFunctions.updateMatchResult,
        params: {
          'p_match_id': matchId,
          'p_home_goals': homeGoals,
          'p_away_goals': awayGoals,
        },
      );

      return MatchResultUpdateResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return MatchResultUpdateResult(
        success: false,
        matchId: matchId,
        homeGoals: homeGoals,
        awayGoals: awayGoals,
        error: e.toString(),
      );
    }
  }

  @override
  Future<FixtureGenerationResult> generateRoundRobinFixtures({
    required String tournamentId,
    DateTime? startDate,
    int daysBetweenMatchdays = 7,
  }) async {
    try {
      final response = await _client.rpc(
        RpcFunctions.generateRoundRobinFixtures,
        params: {
          'p_tournament_id': tournamentId,
          'p_start_date': startDate?.toIso8601String().split('T').first,
          'p_days_between_matchdays': daysBetweenMatchdays,
        },
      );

      return FixtureGenerationResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return FixtureGenerationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> generateFormatAwareFixtures({
    required String tournamentId,
    DateTime? startDate,
    int daysBetweenMatchdays = 7,
  }) async {
    final response = await _client.rpc('generate_tournament_fixtures', params: {
      'p_tournament_id': tournamentId,
      'p_start_date': startDate?.toIso8601String().split('T').first,
      'p_days_between_matchdays': daysBetweenMatchdays,
    });

    return response as Map<String, dynamic>;
  }

  @override
  Future<KnockoutStageGenerationResult> generateGroupKnockoutKnockouts({
    required String tournamentId,
  }) async {
    try {
      final response = await _client.rpc(
        RpcFunctions.generateGroupKnockoutKnockouts,
        params: {
          'p_tournament_id': tournamentId,
        },
      );

      return KnockoutStageGenerationResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return KnockoutStageGenerationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  @override
  Future<void> deleteAllFixtures(String tournamentId) async {
    await _client
        .from(DbTables.matches)
        .delete()
        .eq('tournament_id', tournamentId);
  }

  @override
  Future<List<Match>> getMatchesByTeam(String teamId) async {
    final response = await _client
        .from(DbTables.matches)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .or('home_team_id.eq.$teamId,away_team_id.eq.$teamId')
        .order('kickoff_time');

    return (response as List).map((json) => Match.fromJson(json)).toList();
  }
}
