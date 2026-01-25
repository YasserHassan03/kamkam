import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/match.dart';
import '../data/repositories/match_repository.dart';
import 'repository_providers.dart';
import 'standing_providers.dart';

/// Matches by tournament provider
final matchesByTournamentProvider =
    FutureProvider.family<List<Match>, String>((ref, tournamentId) async {
  try {
    final repo = ref.watch(matchRepositoryProvider);
    return await repo.getMatchesWithTeams(tournamentId);
  } catch (e, stackTrace) {
    debugPrint('ERROR: matchesByTournamentProvider failed for tournament $tournamentId');
    debugPrint('Error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
});

/// Upcoming matches provider
final upcomingMatchesProvider =
    FutureProvider.family<List<Match>, String>((ref, tournamentId) async {
  final repo = ref.watch(matchRepositoryProvider);
  return await repo.getUpcomingMatches(tournamentId);
});

/// Recent results provider
final recentResultsProvider =
    FutureProvider.family<List<Match>, String>((ref, tournamentId) async {
  final repo = ref.watch(matchRepositoryProvider);
  return await repo.getRecentResults(tournamentId);
});

/// Matches by matchday provider
final matchesByMatchdayProvider =
    FutureProvider.family<List<Match>, ({String tournamentId, int matchday})>((ref, params) async {
  final repo = ref.watch(matchRepositoryProvider);
  return await repo.getMatchesByMatchday(params.tournamentId, params.matchday);
});

/// Single match by ID provider
final matchByIdProvider =
    FutureProvider.family<Match?, String>((ref, id) async {
  final repo = ref.watch(matchRepositoryProvider);
  return await repo.getMatchWithTeams(id);
});

/// Helper function to invalidate match providers
void _invalidateMatchProviders(Ref ref, String tournamentId) {
  ref.invalidate(matchesByTournamentProvider(tournamentId));
  ref.invalidate(upcomingMatchesProvider(tournamentId));
  ref.invalidate(recentResultsProvider(tournamentId));
}

/// Create match request class
class CreateMatchRequest {
  final Match match;
  CreateMatchRequest(this.match);
}

/// Update match request class
class UpdateMatchRequest {
  final Match match;
  UpdateMatchRequest(this.match);
}

/// Delete match request class
class DeleteMatchRequest {
  final String id;
  final String tournamentId;
  DeleteMatchRequest(this.id, this.tournamentId);
}

/// Update result request class
class UpdateResultRequest {
  final String matchId;
  final String tournamentId;
  final int homeGoals;
  final int awayGoals;
  UpdateResultRequest({
    required this.matchId,
    required this.tournamentId,
    required this.homeGoals,
    required this.awayGoals,
  });
}

/// Generate fixtures request class
class GenerateFixturesRequest {
  final String tournamentId;
  final DateTime? startDate;
  final int daysBetweenMatchdays;
  GenerateFixturesRequest({
    required this.tournamentId,
    this.startDate,
    this.daysBetweenMatchdays = 7,
  });
}

/// Create match provider
final createMatchProvider =
    FutureProvider.family<Match, CreateMatchRequest>((ref, request) async {
  final repo = ref.watch(matchRepositoryProvider);
  final created = await repo.createMatch(request.match);
  _invalidateMatchProviders(ref, request.match.tournamentId);
  return created;
});

/// Update match provider
final updateMatchProvider =
    FutureProvider.family<Match, UpdateMatchRequest>((ref, request) async {
  final repo = ref.watch(matchRepositoryProvider);
  final updated = await repo.updateMatch(request.match);
  _invalidateMatchProviders(ref, request.match.tournamentId);
  ref.invalidate(matchByIdProvider(request.match.id));
  return updated;
});

/// Delete match provider
final deleteMatchProvider =
    FutureProvider.family<void, DeleteMatchRequest>((ref, request) async {
  final repo = ref.watch(matchRepositoryProvider);
  await repo.deleteMatch(request.id);
  _invalidateMatchProviders(ref, request.tournamentId);
});

/// Update match result provider (transactional with standings)
final updateMatchResultProvider =
    FutureProvider.family<MatchResultUpdateResult, UpdateResultRequest>((ref, request) async {
  final repo = ref.watch(matchRepositoryProvider);
  final result = await repo.updateMatchResult(
    matchId: request.matchId,
    homeGoals: request.homeGoals,
    awayGoals: request.awayGoals,
  );
  
  if (result.success) {
    _invalidateMatchProviders(ref, request.tournamentId);
    ref.invalidate(matchByIdProvider(request.matchId));
    // Also invalidate standings since they're updated transactionally
    ref.invalidate(standingsByTournamentProvider(request.tournamentId));
  }
  
  return result;
});

/// Generate fixtures provider (format-aware)
final generateFixturesProvider =
    FutureProvider.family<FixtureGenerationResult, GenerateFixturesRequest>((ref, request) async {
  final repo = ref.watch(matchRepositoryProvider);
  try {
    final response = await repo.generateFormatAwareFixtures(
      tournamentId: request.tournamentId,
      startDate: request.startDate,
      daysBetweenMatchdays: request.daysBetweenMatchdays,
    ).timeout(const Duration(seconds: 120)); // Increased to 2 minutes for large tournaments

    final result = FixtureGenerationResult.fromJson(response);

    if (result.success) {
      _invalidateMatchProviders(ref, request.tournamentId);
    }

    return result;
  } on TimeoutException {
    throw Exception('Fixture generation timed out');
  } catch (e) {
    throw Exception('Error generating fixtures: $e');
  }
});

/// Delete all fixtures provider
final deleteAllFixturesProvider =
    FutureProvider.family<void, String>((ref, tournamentId) async {
  final repo = ref.watch(matchRepositoryProvider);
  await repo.deleteAllFixtures(tournamentId);
  _invalidateMatchProviders(ref, tournamentId);
});

/// Generate knockout stage for group_knockout tournaments (after group stage completion)
final generateGroupKnockoutKnockoutsProvider =
    FutureProvider.family<KnockoutStageGenerationResult, String>((ref, tournamentId) async {
  final repo = ref.watch(matchRepositoryProvider);
  final result = await repo.generateGroupKnockoutKnockouts(tournamentId: tournamentId);
  if (result.success) {
    _invalidateMatchProviders(ref, tournamentId);
    ref.invalidate(bracketByTournamentProvider(tournamentId));
  }
  return result;
});

/// Bracket provider - groups matches by round (useful for knockout brackets)
final bracketByTournamentProvider =
    FutureProvider.family<Map<int, List<Match>>, String>((ref, tournamentId) async {
  try {
    final matches = await ref.watch(matchesByTournamentProvider(tournamentId).future);

    // Filter matches which are part of knockout/round structure (round_number present)
    final bracketMatches = matches.where((m) => m.roundNumber != null).toList();

    final Map<int, List<Match>> grouped = {};
    for (final m in bracketMatches) {
      final r = m.roundNumber!;
      grouped.putIfAbsent(r, () => []).add(m);
    }

    // Sort matches per round by seed or kickoff
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) {
        // Prefer pairing siblings by nextMatchId to keep bracket visually coherent.
        final aParent = a.nextMatchId ?? '';
        final bParent = b.nextMatchId ?? '';
        final parentCmp = aParent.compareTo(bParent);
        if (parentCmp != 0) return parentCmp;

        final aKick = a.kickoffTime?.millisecondsSinceEpoch ?? 0;
        final bKick = b.kickoffTime?.millisecondsSinceEpoch ?? 0;
        final kickCmp = aKick.compareTo(bKick);
        if (kickCmp != 0) return kickCmp;

        return a.id.compareTo(b.id);
      });
    }

    return grouped;
  } catch (e, stackTrace) {
    debugPrint('ERROR: bracketByTournamentProvider failed for tournament $tournamentId');
    debugPrint('Error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
});

