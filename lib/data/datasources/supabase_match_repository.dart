import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
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
        .order('matchday', ascending: true)
        .order('kickoff_time', ascending: true);

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
        .order('matchday', ascending: true)
        .order('kickoff_time', ascending: true);

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
        .order('matchday', ascending: true)
        .order('kickoff_time', ascending: true)
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
    int? homePenaltyGoals,
    int? awayPenaltyGoals,
  }) async {
    try {
      final response = await _client.rpc(
        RpcFunctions.updateMatchResult,
        params: {
          'p_match_id': matchId,
          'p_home_goals': homeGoals,
          'p_away_goals': awayGoals,
          'p_home_penalty_goals': homePenaltyGoals,
          'p_away_penalty_goals': awayPenaltyGoals,
        },
      );

      return MatchResultUpdateResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return MatchResultUpdateResult(
        success: false,
        matchId: matchId,
        homeGoals: homeGoals,
        awayGoals: awayGoals,
        homePenaltyGoals: homePenaltyGoals,
        awayPenaltyGoals: awayPenaltyGoals,
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

  /// Start a match (set status to inProgress)
  Future<Match> startMatch(String matchId) async {
    final response = await _client
        .from(DbTables.matches)
        .update({
          'status': MatchStatus.inProgress.jsonValue,
          'home_goals': 0,
          'away_goals': 0,
          'is_clock_running': true,
          'clock_start_time': DateTime.now().toUtc().toIso8601String(),
          'accumulated_seconds': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', matchId)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .single();

    return Match.fromJson(response);
  }

  /// End a match (set status to finished)
  Future<Match> endMatch(String matchId) async {
    final response = await _client
        .from(DbTables.matches)
        .update({
          'status': 'finished',
          'is_clock_running': false,
          'clock_start_time': null,
          // accumulated_seconds is handled by DB trigger, but safe to set here if needed
        })
        .eq('id', matchId)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .single();

    return Match.fromJson(response);
  }

  /// Update live match score
  Future<Match> updateLiveScore({
    required String matchId,
    required int homeGoals,
    required int awayGoals,
  }) async {
    final response = await _client
        .from(DbTables.matches)
        .update({
          'home_goals': homeGoals,
          'away_goals': awayGoals,
        })
        .eq('id', matchId)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .single();

    return Match.fromJson(response);
  }

  /// Subscribe to real-time match updates
  Stream<Match> subscribeToMatch(String matchId) {
    return _client
        .from(DbTables.matches)
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((data) => data.isNotEmpty ? Match.fromJson(data.first) : throw Exception('Match not found'));
  }

  /// Get all live matches for a tournament
  @override
  Future<List<Match>> getLiveMatches(String tournamentId) async {
    final response = await _client
        .from(DbTables.matches)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .eq('tournament_id', tournamentId)
        .eq('status', 'in_progress')
        .order('matchday', ascending: true)
        .order('kickoff_time', ascending: true);

    return (response as List).map((json) => Match.fromJson(json)).toList();
  }

  @override
  Future<Match> toggleMatchClock(Match match, bool start) async {
    final now = DateTime.now().toUtc();
    final Map<String, dynamic> updates = {
      'is_clock_running': start,
      'updated_at': now.toIso8601String(),
    };

    if (start) {
      // Starting or Resuming
      updates['clock_start_time'] = now.toIso8601String();
    } else {
      // Pausing
      updates['clock_start_time'] = null;
      updates['accumulated_seconds'] = match.elapsedSeconds;
    }

    final response = await _client
        .from(DbTables.matches)
        .update(updates)
        .eq('id', match.id)
        .select('''
          *,
          home_team:teams!matches_home_team_id_fkey(*),
          away_team:teams!matches_away_team_id_fkey(*)
        ''')
        .single();

    return Match.fromJson(response);
  }
}

