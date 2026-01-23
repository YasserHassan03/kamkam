import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/tournament.dart';
import 'repository_providers.dart';
import 'match_providers.dart';

/// Public tournaments provider
final publicTournamentsProvider = FutureProvider<List<Tournament>>((ref) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return await repo.getPublicTournaments();
});

/// Active tournaments provider
final activeTournamentsProvider = FutureProvider<List<Tournament>>((ref) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return await repo.getActiveTournaments();
});

/// Tournaments by organisation provider
final tournamentsByOrgProvider =
    FutureProvider.family<List<Tournament>, String>((ref, orgId) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return await repo.getTournamentsByOrganisation(orgId);
});

/// Single tournament by ID provider
final tournamentByIdProvider =
    FutureProvider.family<Tournament?, String>((ref, id) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return await repo.getTournamentById(id);
});

/// Tournament search provider
final tournamentSearchProvider =
    FutureProvider.family<List<Tournament>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repo = ref.watch(tournamentRepositoryProvider);
  return await repo.searchTournaments(query);
});

/// Create tournament provider
final createTournamentProvider =
    FutureProvider.family<Tournament, Tournament>((ref, tournament) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  final created = await repo.createTournament(tournament);
  ref.invalidate(publicTournamentsProvider);
  ref.invalidate(activeTournamentsProvider);
  ref.invalidate(tournamentsByOrgProvider(tournament.orgId));
  return created;
});

/// Update tournament provider
final updateTournamentProvider =
    FutureProvider.family<Tournament, Tournament>((ref, tournament) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  final updated = await repo.updateTournament(tournament);
  ref.invalidate(publicTournamentsProvider);
  ref.invalidate(activeTournamentsProvider);
  ref.invalidate(tournamentsByOrgProvider(tournament.orgId));
  ref.invalidate(tournamentByIdProvider(tournament.id));
  return updated;
});

/// Delete tournament provider
final deleteTournamentProvider =
    FutureProvider.family<void, String>((ref, id) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  // Get tournament before delete to invalidate org/user lists
  final tournament = await repo.getTournamentById(id);
  await repo.deleteTournament(id);
  ref.invalidate(publicTournamentsProvider);
  ref.invalidate(activeTournamentsProvider);
  if (tournament != null) {
    ref.invalidate(tournamentsByOrgProvider(tournament.orgId));
    ref.invalidate(userTournamentsProvider(tournament.ownerId));
  }
  ref.invalidate(tournamentByIdProvider(id));
});

/// Tournaments created by the logged-in user provider
final userTournamentsProvider =
    FutureProvider.family<List<Tournament>, String>((ref, userId) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return await repo.getUserTournaments(userId);
});

/// All tournaments provider (admin only) - auto-refreshes every 5 seconds
final allTournamentsProvider = StreamProvider<List<Tournament>>((ref) async* {
  final repo = ref.watch(tournamentRepositoryProvider);
  
  // Initial load
  try {
    final tournaments = await repo.getAllTournaments();
    yield tournaments;
  } catch (e) {
    rethrow;
  }
  
  // Poll every 5 seconds for new/updated tournaments
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    try {
      final tournaments = await repo.getAllTournaments();
      yield tournaments;
    } catch (e) {
      // Continue polling even on error
    }
  }
});

/// Toggle tournament visibility (hide/show) for admin
final toggleTournamentVisibilityProvider =
    FutureProvider.family<Tournament, ({String tournamentId, bool hidden})>((ref, params) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  final updated = await repo.toggleTournamentVisibility(params.tournamentId, params.hidden);
  // Invalidate all relevant providers to refresh UI
  ref.invalidate(publicTournamentsProvider);
  ref.invalidate(activeTournamentsProvider);
  ref.invalidate(tournamentByIdProvider(params.tournamentId));
  ref.invalidate(allTournamentsProvider); // CRITICAL: Invalidate the list provider
  // Invalidate org tournaments if we have the tournament
  final tournament = await repo.getTournamentById(params.tournamentId);
  if (tournament != null) {
    ref.invalidate(tournamentsByOrgProvider(tournament.orgId));
  }
  return updated;
});

/// Generate teams and fixtures for a tournament (format-aware)
final generateTeamsAndFixturesProvider =
    FutureProvider.family<void, ({String tournamentId, int teamCount})>((ref, params) async {
  final tournamentRepo = ref.watch(tournamentRepositoryProvider);
  final matchRepo = ref.watch(matchRepositoryProvider);

  // Generate teams
  await tournamentRepo.generateTeams(params.tournamentId, params.teamCount);

  // Generate fixtures using format-aware RPC with timeout and propagate any error back
  try {
    final response = await matchRepo
        .generateFormatAwareFixtures(tournamentId: params.tournamentId)
        .timeout(const Duration(seconds: 30));
    final success = response['success'] as bool? ?? false;
    if (!success) {
      final err = response['error'] as String? ?? 'Unknown error generating fixtures';
      throw Exception(err);
    }
  } on TimeoutException {
    throw Exception('Fixture generation timed out');
  } catch (e) {
    throw Exception('Error generating fixtures: $e');
  }

  // Invalidate related providers
  ref.invalidate(tournamentByIdProvider(params.tournamentId));
  ref.invalidate(matchesByTournamentProvider(params.tournamentId));
});
