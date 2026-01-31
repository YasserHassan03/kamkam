import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/standing.dart';
import 'repository_providers.dart';

/// Standings by tournament provider (sorted by position)
final standingsByTournamentProvider =
    FutureProvider.family<List<Standing>, String>((ref, tournamentId) async {
  final repo = ref.watch(standingRepositoryProvider);
  return await repo.getStandingsWithTeams(tournamentId);
});

/// Auto-refreshing standings provider (polls every minute)
final standingsByTournamentStreamProvider =
    StreamProvider.family<List<Standing>, String>((ref, tournamentId) async* {
  final repo = ref.watch(standingRepositoryProvider);

  // Initial load
  final initial = await repo.getStandingsWithTeams(tournamentId);
  yield initial;

  // Poll every 60 seconds
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    try {
      final updated = await repo.getStandingsWithTeams(tournamentId);
      yield updated;
    } catch (e) {
      // Continue polling on error
    }
  }
});

/// Single team standing provider
final teamStandingProvider =
    FutureProvider.family<Standing?, ({String tournamentId, String teamId})>((ref, params) async {
  final repo = ref.watch(standingRepositoryProvider);
  return await repo.getStandingByTeam(params.tournamentId, params.teamId);
});

/// Reset standings provider
final resetStandingsProvider =
    FutureProvider.family<void, String>((ref, tournamentId) async {
  final repo = ref.watch(standingRepositoryProvider);
  await repo.resetStandings(tournamentId);
  ref.invalidate(standingsByTournamentProvider(tournamentId));
});

