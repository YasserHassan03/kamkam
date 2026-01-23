import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/team.dart';
import 'repository_providers.dart';

/// Teams by tournament provider
final teamsByTournamentProvider =
    FutureProvider.family<List<Team>, String>((ref, tournamentId) async {
  final repo = ref.watch(teamRepositoryProvider);
  return await repo.getTeamsByTournament(tournamentId);
});

/// Single team by ID provider
final teamByIdProvider =
    FutureProvider.family<Team?, String>((ref, id) async {
  final repo = ref.watch(teamRepositoryProvider);
  return await repo.getTeamById(id);
});

/// Team count by tournament provider
final teamCountProvider =
    FutureProvider.family<int, String>((ref, tournamentId) async {
  final repo = ref.watch(teamRepositoryProvider);
  return await repo.getTeamCount(tournamentId);
});

/// Create team request class
class CreateTeamRequest {
  final Team team;
  CreateTeamRequest(this.team);
}

/// Create teams batch request class
class CreateTeamsBatchRequest {
  final List<Team> teams;
  CreateTeamsBatchRequest(this.teams);
}

/// Update team request class
class UpdateTeamRequest {
  final Team team;
  UpdateTeamRequest(this.team);
}

/// Delete team request class
class DeleteTeamRequest {
  final String id;
  final String tournamentId;
  DeleteTeamRequest(this.id, this.tournamentId);
}

/// Create team provider
final createTeamProvider =
    FutureProvider.family<Team, CreateTeamRequest>((ref, request) async {
  final repo = ref.watch(teamRepositoryProvider);
  final created = await repo.createTeam(request.team);
  ref.invalidate(teamsByTournamentProvider(request.team.tournamentId));
  ref.invalidate(teamCountProvider(request.team.tournamentId));
  return created;
});

/// Create teams batch provider
final createTeamsBatchProvider =
    FutureProvider.family<List<Team>, CreateTeamsBatchRequest>((ref, request) async {
  if (request.teams.isEmpty) return [];
  final repo = ref.watch(teamRepositoryProvider);
  final created = await repo.createTeams(request.teams);
  ref.invalidate(teamsByTournamentProvider(request.teams.first.tournamentId));
  ref.invalidate(teamCountProvider(request.teams.first.tournamentId));
  return created;
});

/// Update team provider
final updateTeamProvider =
    FutureProvider.family<Team, UpdateTeamRequest>((ref, request) async {
  final repo = ref.watch(teamRepositoryProvider);
  final updated = await repo.updateTeam(request.team);
  ref.invalidate(teamsByTournamentProvider(request.team.tournamentId));
  ref.invalidate(teamByIdProvider(request.team.id));
  return updated;
});

/// Delete team provider
final deleteTeamProvider =
    FutureProvider.family<void, DeleteTeamRequest>((ref, request) async {
  final repo = ref.watch(teamRepositoryProvider);
  await repo.deleteTeam(request.id);
  ref.invalidate(teamsByTournamentProvider(request.tournamentId));
  ref.invalidate(teamCountProvider(request.tournamentId));
});

