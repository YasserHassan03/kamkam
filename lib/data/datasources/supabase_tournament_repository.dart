import 'package:flutter/foundation.dart';
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
    // Filter by visibility, exclude drafts, and exclude admin-hidden tournaments
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .eq('visibility', 'public')
        .neq('status', 'draft') // Exclude draft tournaments
        .eq('hidden_by_admin', false) // Exclude admin-hidden tournaments
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      // Ensure all required fields have values and handle nulls safely
      final safeJson = Map<String, dynamic>.from(json);
      
      // Safely convert all fields to strings if needed
      safeJson['id'] = safeJson['id']?.toString() ?? '';
      safeJson['org_id'] = safeJson['org_id']?.toString() ?? '';
      safeJson['owner_id'] = safeJson['owner_id']?.toString() ?? '';
      safeJson['name'] = safeJson['name']?.toString() ?? '';
      safeJson['season_year'] = safeJson['season_year'] ?? DateTime.now().year;
      safeJson['status'] = safeJson['status']?.toString() ?? 'draft';
      safeJson['visibility'] = safeJson['visibility']?.toString() ?? 'public';
      safeJson['format'] = safeJson['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeJson['start_date'] != null) {
        safeJson['start_date'] = safeJson['start_date'].toString();
      }
      if (safeJson['end_date'] != null) {
        safeJson['end_date'] = safeJson['end_date'].toString();
      }
      if (safeJson['created_at'] != null) {
        safeJson['created_at'] = safeJson['created_at'].toString();
      }
      if (safeJson['updated_at'] != null) {
        safeJson['updated_at'] = safeJson['updated_at'].toString();
      }
      
      return Tournament.fromJson(safeJson);
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

    return (response as List).map((json) {
      // Ensure all required fields have values and handle nulls safely
      final safeJson = Map<String, dynamic>.from(json);
      
      // Safely convert all fields to strings if needed
      safeJson['id'] = safeJson['id']?.toString() ?? '';
      safeJson['org_id'] = safeJson['org_id']?.toString() ?? '';
      safeJson['owner_id'] = safeJson['owner_id']?.toString() ?? '';
      safeJson['name'] = safeJson['name']?.toString() ?? '';
      safeJson['season_year'] = safeJson['season_year'] ?? DateTime.now().year;
      safeJson['status'] = safeJson['status']?.toString() ?? 'draft';
      safeJson['visibility'] = safeJson['visibility']?.toString() ?? 'public';
      safeJson['format'] = safeJson['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeJson['start_date'] != null) {
        safeJson['start_date'] = safeJson['start_date'].toString();
      }
      if (safeJson['end_date'] != null) {
        safeJson['end_date'] = safeJson['end_date'].toString();
      }
      if (safeJson['created_at'] != null) {
        safeJson['created_at'] = safeJson['created_at'].toString();
      }
      if (safeJson['updated_at'] != null) {
        safeJson['updated_at'] = safeJson['updated_at'].toString();
      }
      
      return Tournament.fromJson(safeJson);
    }).toList();
  }

  @override
  Future<Tournament?> getTournamentById(String id) async {
    dynamic response;
    try {
      response = await _client
          .from(DbTables.tournaments)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      
      // Ensure all required fields have values and handle nulls safely
      final safeResponse = Map<String, dynamic>.from(response);
      
      // Safely handle all potentially null String fields
      safeResponse['id'] = safeResponse['id']?.toString() ?? '';
      safeResponse['org_id'] = safeResponse['org_id']?.toString() ?? '';
      safeResponse['owner_id'] = safeResponse['owner_id']?.toString() ?? '';
      safeResponse['name'] = safeResponse['name']?.toString() ?? '';
      safeResponse['season_year'] = safeResponse['season_year'] ?? DateTime.now().year;
      safeResponse['status'] = safeResponse['status']?.toString() ?? 'draft';
      safeResponse['visibility'] = safeResponse['visibility']?.toString() ?? 'public';
      safeResponse['format'] = safeResponse['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeResponse['start_date'] != null) {
        safeResponse['start_date'] = safeResponse['start_date'].toString();
      }
      if (safeResponse['end_date'] != null) {
        safeResponse['end_date'] = safeResponse['end_date'].toString();
      }
      if (safeResponse['created_at'] != null) {
        safeResponse['created_at'] = safeResponse['created_at'].toString();
      }
      if (safeResponse['updated_at'] != null) {
        safeResponse['updated_at'] = safeResponse['updated_at'].toString();
      }
      
      try {
        final tournament = Tournament.fromJson(safeResponse);
        // Validate the tournament object was created successfully
        if (tournament.id.isEmpty) {
          debugPrint('WARNING: Tournament created with empty ID');
        }
        return tournament;
      } catch (parseError, parseStackTrace) {
        // Log parsing error with full details
        debugPrint('ERROR: Failed to parse tournament JSON for id $id');
        debugPrint('Parse error: $parseError');
        debugPrint('Parse error type: ${parseError.runtimeType}');
        debugPrint('Parse stack trace: $parseStackTrace');
        debugPrint('Raw response type: ${response.runtimeType}');
        debugPrint('Raw response: $response');
        debugPrint('Safe response: $safeResponse');
        if (parseError is TypeError) {
          debugPrint('TypeError message: ${parseError.toString()}');
          debugPrint('TypeError stack: ${parseError.stackTrace}');
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      // Log error with stack trace for debugging
      debugPrint('Error loading tournament $id: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Response data: $response');
      return null;
    }
  }

  @override
  Future<Tournament> createTournament(Tournament tournament) async {
    final response = await _client
        .from(DbTables.tournaments)
        .insert(tournament.toInsertJson())
        .select()
        .single();

    // Ensure all required fields have values and handle nulls safely
    final safeResponse = Map<String, dynamic>.from(response);
    
    // Safely convert all fields to strings if needed
    safeResponse['id'] = safeResponse['id']?.toString() ?? tournament.id;
    safeResponse['org_id'] = safeResponse['org_id']?.toString() ?? tournament.orgId;
    safeResponse['owner_id'] = safeResponse['owner_id']?.toString() ?? tournament.ownerId;
    safeResponse['name'] = safeResponse['name']?.toString() ?? tournament.name;
    safeResponse['season_year'] = safeResponse['season_year'] ?? tournament.seasonYear;
    safeResponse['status'] = safeResponse['status']?.toString() ?? tournament.status.name;
    safeResponse['visibility'] = safeResponse['visibility']?.toString() ?? tournament.visibility.name;
    safeResponse['format'] = safeResponse['format']?.toString() ?? tournament.format;
    
    // Safely handle date fields
    if (safeResponse['start_date'] != null) {
      safeResponse['start_date'] = safeResponse['start_date'].toString();
    }
    if (safeResponse['end_date'] != null) {
      safeResponse['end_date'] = safeResponse['end_date'].toString();
    }
    if (safeResponse['created_at'] != null) {
      safeResponse['created_at'] = safeResponse['created_at'].toString();
    }
    if (safeResponse['updated_at'] != null) {
      safeResponse['updated_at'] = safeResponse['updated_at'].toString();
    }

    return Tournament.fromJson(safeResponse);
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
          'visibility': tournament.visibility.name,
          'format': tournament.format,
          'group_count': tournament.groupCount,
          'qualifiers_per_group': tournament.qualifiersPerGroup,
          'rules_json': tournament.rules.toJson(),
          'hidden_by_admin': tournament.hiddenByAdmin,
          'sponsor_logo_url': tournament.sponsorLogoUrl,
        })
        .eq('id', tournament.id)
        .select()
        .single();

      // Ensure all required fields have values and handle nulls safely
      final safeResponse = Map<String, dynamic>.from(response);
      
      // Safely convert all fields to strings if needed
      safeResponse['id'] = safeResponse['id']?.toString() ?? tournament.id;
      safeResponse['org_id'] = safeResponse['org_id']?.toString() ?? tournament.orgId;
      safeResponse['owner_id'] = safeResponse['owner_id']?.toString() ?? tournament.ownerId;
      safeResponse['name'] = safeResponse['name']?.toString() ?? tournament.name;
      safeResponse['season_year'] = safeResponse['season_year'] ?? tournament.seasonYear;
      safeResponse['status'] = safeResponse['status']?.toString() ?? tournament.status.name;
      safeResponse['visibility'] = safeResponse['visibility']?.toString() ?? tournament.visibility.name;
      safeResponse['format'] = safeResponse['format']?.toString() ?? tournament.format;
      
      // Safely handle date fields
      if (safeResponse['start_date'] != null) {
        safeResponse['start_date'] = safeResponse['start_date'].toString();
      }
      if (safeResponse['end_date'] != null) {
        safeResponse['end_date'] = safeResponse['end_date'].toString();
      }
      if (safeResponse['created_at'] != null) {
        safeResponse['created_at'] = safeResponse['created_at'].toString();
      }
      if (safeResponse['updated_at'] != null) {
        safeResponse['updated_at'] = safeResponse['updated_at'].toString();
      }

      return Tournament.fromJson(safeResponse);
  }

  /// Toggle hide/show tournament for admin (overrides organiser visibility)
  Future<Tournament> toggleTournamentVisibility(String tournamentId, bool hidden) async {
    final response = await _client
        .from(DbTables.tournaments)
        .update({
          'hidden_by_admin': hidden,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tournamentId)
        .select()
        .single();

      // Ensure all required fields have values and handle nulls safely
      final safeResponse = Map<String, dynamic>.from(response);
      
      // Safely convert all fields to strings if needed
      safeResponse['id'] = safeResponse['id']?.toString() ?? tournamentId;
      safeResponse['org_id'] = safeResponse['org_id']?.toString() ?? '';
      safeResponse['owner_id'] = safeResponse['owner_id']?.toString() ?? '';
      safeResponse['name'] = safeResponse['name']?.toString() ?? '';
      safeResponse['season_year'] = safeResponse['season_year'] ?? DateTime.now().year;
      safeResponse['status'] = safeResponse['status']?.toString() ?? 'draft';
      safeResponse['visibility'] = safeResponse['visibility']?.toString() ?? 'public';
      safeResponse['format'] = safeResponse['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeResponse['start_date'] != null) {
        safeResponse['start_date'] = safeResponse['start_date'].toString();
      }
      if (safeResponse['end_date'] != null) {
        safeResponse['end_date'] = safeResponse['end_date'].toString();
      }
      if (safeResponse['created_at'] != null) {
        safeResponse['created_at'] = safeResponse['created_at'].toString();
      }
      if (safeResponse['updated_at'] != null) {
        safeResponse['updated_at'] = safeResponse['updated_at'].toString();
      }

      return Tournament.fromJson(safeResponse);
  }

  @override
  Future<void> deleteTournament(String id) async {
    await _client.from(DbTables.tournaments).delete().eq('id', id);
  }

  @override
  Future<List<Tournament>> getAllTournaments() async {
    // Admin can see all tournaments regardless of visibility or status
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      // Ensure all required fields have values and handle nulls safely
      final safeJson = Map<String, dynamic>.from(json);
      
      // Safely convert all fields to strings if needed
      safeJson['id'] = safeJson['id']?.toString() ?? '';
      safeJson['org_id'] = safeJson['org_id']?.toString() ?? '';
      safeJson['owner_id'] = safeJson['owner_id']?.toString() ?? '';
      safeJson['name'] = safeJson['name']?.toString() ?? '';
      safeJson['season_year'] = safeJson['season_year'] ?? DateTime.now().year;
      safeJson['status'] = safeJson['status']?.toString() ?? 'draft';
      safeJson['visibility'] = safeJson['visibility']?.toString() ?? 'public';
      safeJson['format'] = safeJson['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeJson['start_date'] != null) {
        safeJson['start_date'] = safeJson['start_date'].toString();
      }
      if (safeJson['end_date'] != null) {
        safeJson['end_date'] = safeJson['end_date'].toString();
      }
      if (safeJson['created_at'] != null) {
        safeJson['created_at'] = safeJson['created_at'].toString();
      }
      if (safeJson['updated_at'] != null) {
        safeJson['updated_at'] = safeJson['updated_at'].toString();
      }
      
      return Tournament.fromJson(safeJson);
    }).toList();
  }

  @override
  Future<List<Tournament>> getActiveTournaments() async {
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .eq('status', 'active')
        .eq('visibility', 'public')
        .eq('hidden_by_admin', false) // Exclude admin-hidden tournaments
        .order('start_date', ascending: true);

    return (response as List).map((json) {
      // Ensure all required fields have values and handle nulls safely
      final safeJson = Map<String, dynamic>.from(json);
      
      // Safely convert all fields to strings if needed
      safeJson['id'] = safeJson['id']?.toString() ?? '';
      safeJson['org_id'] = safeJson['org_id']?.toString() ?? '';
      safeJson['owner_id'] = safeJson['owner_id']?.toString() ?? '';
      safeJson['name'] = safeJson['name']?.toString() ?? '';
      safeJson['season_year'] = safeJson['season_year'] ?? DateTime.now().year;
      safeJson['status'] = safeJson['status']?.toString() ?? 'draft';
      safeJson['visibility'] = safeJson['visibility']?.toString() ?? 'public';
      safeJson['format'] = safeJson['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeJson['start_date'] != null) {
        safeJson['start_date'] = safeJson['start_date'].toString();
      }
      if (safeJson['end_date'] != null) {
        safeJson['end_date'] = safeJson['end_date'].toString();
      }
      if (safeJson['created_at'] != null) {
        safeJson['created_at'] = safeJson['created_at'].toString();
      }
      if (safeJson['updated_at'] != null) {
        safeJson['updated_at'] = safeJson['updated_at'].toString();
      }
      
      return Tournament.fromJson(safeJson);
    }).toList();
  }

  @override
  Future<List<Tournament>> searchTournaments(String query) async {
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .eq('visibility', 'public')
        .ilike('name', '%$query%')
        .order('name')
        .limit(20);

    return (response as List).map((json) {
      // Ensure all required fields have values and handle nulls safely
      final safeJson = Map<String, dynamic>.from(json);
      
      // Safely convert all fields to strings if needed
      safeJson['id'] = safeJson['id']?.toString() ?? '';
      safeJson['org_id'] = safeJson['org_id']?.toString() ?? '';
      safeJson['owner_id'] = safeJson['owner_id']?.toString() ?? '';
      safeJson['name'] = safeJson['name']?.toString() ?? '';
      safeJson['season_year'] = safeJson['season_year'] ?? DateTime.now().year;
      safeJson['status'] = safeJson['status']?.toString() ?? 'draft';
      safeJson['visibility'] = safeJson['visibility']?.toString() ?? 'public';
      safeJson['format'] = safeJson['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeJson['start_date'] != null) {
        safeJson['start_date'] = safeJson['start_date'].toString();
      }
      if (safeJson['end_date'] != null) {
        safeJson['end_date'] = safeJson['end_date'].toString();
      }
      if (safeJson['created_at'] != null) {
        safeJson['created_at'] = safeJson['created_at'].toString();
      }
      if (safeJson['updated_at'] != null) {
        safeJson['updated_at'] = safeJson['updated_at'].toString();
      }
      
      return Tournament.fromJson(safeJson);
    }).toList();
  }

  @override
  Future<List<Tournament>> getUserTournaments(String ownerId) async {
    final response = await _client
        .from(DbTables.tournaments)
        .select()
        .eq('owner_id', ownerId) // Filter by owner ID
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      // Ensure all required fields have values and handle nulls safely
      final safeJson = Map<String, dynamic>.from(json);
      
      // Safely convert all fields to strings if needed
      safeJson['id'] = safeJson['id']?.toString() ?? '';
      safeJson['org_id'] = safeJson['org_id']?.toString() ?? '';
      safeJson['owner_id'] = safeJson['owner_id']?.toString() ?? '';
      safeJson['name'] = safeJson['name']?.toString() ?? '';
      safeJson['season_year'] = safeJson['season_year'] ?? DateTime.now().year;
      safeJson['status'] = safeJson['status']?.toString() ?? 'draft';
      safeJson['visibility'] = safeJson['visibility']?.toString() ?? 'public';
      safeJson['format'] = safeJson['format']?.toString() ?? 'league';
      
      // Safely handle date fields
      if (safeJson['start_date'] != null) {
        safeJson['start_date'] = safeJson['start_date'].toString();
      }
      if (safeJson['end_date'] != null) {
        safeJson['end_date'] = safeJson['end_date'].toString();
      }
      if (safeJson['created_at'] != null) {
        safeJson['created_at'] = safeJson['created_at'].toString();
      }
      if (safeJson['updated_at'] != null) {
        safeJson['updated_at'] = safeJson['updated_at'].toString();
      }
      
      return Tournament.fromJson(safeJson);
    }).toList();
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
