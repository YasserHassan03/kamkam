import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/standing.dart';
import 'repository_providers.dart';

/// Standings by tournament provider (sorted by position)
final standingsByTournamentProvider =
    FutureProvider.family<List<Standing>, String>((ref, tournamentId) async {
  final repo = ref.watch(standingRepositoryProvider);
  return await repo.getStandingsWithTeams(tournamentId);
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

