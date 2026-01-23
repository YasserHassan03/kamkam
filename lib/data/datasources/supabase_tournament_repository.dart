import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/tournament.dart';
import '../repositories/tournament_repository.dart';

/// Supabase implementation of TournamentRepository
class SupabaseTournamentRepository implements TournamentRepository {
  final SupabaseClient _client;

  SupabaseTournamentRepository(this._client);

  @override
  Future<List<Tournament>> getPublicTournaments() async {
    // Join with organisations to filter by visibility and exclude drafts
    final response = await _client
        .from(DbTables.tournaments)
        .select('''
          *,
          organisations!inner(visibility)
        ''')
        .eq('organisations.visibility', 'public')
        .neq('status', 'draft') // Exclude draft tournaments
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      // Remove the joined organisation data before parsing
      final tournamentJson = Map<String, dynamic>.from(json);
      tournamentJson.remove('organisations');
      return Tournament.fromJson(tournamentJson);
    }).toList();
  }

  @override
  Future<List<Tournament>> getTournamentsByOrganisation(String orgId) async {
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .eq('org_id', orgId)
        .order('season_year', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Tournament.fromJson(json))
        .toList();
  }

  @override
  Future<Tournament?> getTournamentById(String id) async {
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Tournament.fromJson(response);
  }

  @override
  Future<Tournament> createTournament(Tournament tournament) async {
    final response = await _client
        .from(DbTables.tournaments)
        .insert(tournament.toInsertJson())
        .select()
        .single();

    return Tournament.fromJson(response);
  }

  @override
  Future<Tournament> updateTournament(Tournament tournament) async {
    final response = await _client
        .from(DbTables.tournaments)
        .update({
          'name': tournament.name,
          'season_year': tournament.seasonYear,
          'start_date': tournament.startDate?.toIso8601String().split('T').first,
          'end_date': tournament.endDate?.toIso8601String().split('T').first,
          'status': tournament.status.name,
          'rules_json': tournament.rules.toJson(),
        })
        .eq('id', tournament.id)
        .select()
        .single();

    return Tournament.fromJson(response);
  }

  @override
  Future<void> deleteTournament(String id) async {
    await _client.from(DbTables.tournaments).delete().eq('id', id);
  }

  @override
  Future<List<Tournament>> getActiveTournaments() async {
    final response = await _client
        .from(DbTables.tournaments)
        .select('''
          *,
          organisations!inner(visibility)
        ''')
        .eq('status', 'active')
        .eq('organisations.visibility', 'public')
        .order('start_date', ascending: true);

    return (response as List).map((json) {
      final tournamentJson = Map<String, dynamic>.from(json);
      tournamentJson.remove('organisations');
      return Tournament.fromJson(tournamentJson);
    }).toList();
  }

  @override
  Future<List<Tournament>> searchTournaments(String query) async {
    final response = await _client
        .from(DbTables.tournaments)
        .select('''
          *,
          organisations!inner(visibility)
        ''')
        .eq('organisations.visibility', 'public')
        .ilike('name', '%$query%')
        .order('name')
        .limit(20);

    return (response as List).map((json) {
      final tournamentJson = Map<String, dynamic>.from(json);
      tournamentJson.remove('organisations');
      return Tournament.fromJson(tournamentJson);
    }).toList();
  }

  @override
  Future<List<Tournament>> getUserTournaments(String orgId) async {
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .eq('org_id', orgId) // Filter by org ID
        .order('created_at', ascending: false);

    return (response as List).map((json) => Tournament.fromJson(json)).toList();
  }

  @override
  Future<void> generateTeams(String tournamentId, int teamCount) async {
    final teams = List.generate(teamCount, (index) => {
      'tournament_id': tournamentId,
      'name': 'Team ${String.fromCharCode(65 + index)}', // Team A, Team B, etc.
      'short_name': 'T${String.fromCharCode(65 + index)}',
    });

    await _client.from(DbTables.teams).insert(teams);
  }

  @override
  Future<Map<String, dynamic>> generateFixtures(String tournamentId) async {
    final response = await _client
        .rpc('generate_tournament_fixtures', params: {
          'p_tournament_id': tournamentId,
        });

    return response as Map<String, dynamic>;
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
}
