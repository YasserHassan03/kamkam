import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/player.dart';
import 'repository_providers.dart';

/// Players by team provider
final playersByTeamProvider =
    FutureProvider.family<List<Player>, String>((ref, teamId) async {
  final repo = ref.watch(playerRepositoryProvider);
  return await repo.getPlayersByTeam(teamId);
});

/// Single player by ID provider
final playerByIdProvider =
    FutureProvider.family<Player?, String>((ref, id) async {
  final repo = ref.watch(playerRepositoryProvider);
  return await repo.getPlayerById(id);
});

/// Player count by team provider
final playerCountProvider =
    FutureProvider.family<int, String>((ref, teamId) async {
  final repo = ref.watch(playerRepositoryProvider);
  return await repo.getPlayerCount(teamId);
});

/// Create player request class
class CreatePlayerRequest {
  final Player player;
  CreatePlayerRequest(this.player);
}

/// Create players batch request class
class CreatePlayersBatchRequest {
  final List<Player> players;
  CreatePlayersBatchRequest(this.players);
}

/// Update player request class
class UpdatePlayerRequest {
  final Player player;
  UpdatePlayerRequest(this.player);
}

/// Delete player request class
class DeletePlayerRequest {
  final String id;
  final String teamId;
  DeletePlayerRequest(this.id, this.teamId);
}

/// Create player provider
final createPlayerProvider =
    FutureProvider.family<Player, CreatePlayerRequest>((ref, request) async {
  final repo = ref.watch(playerRepositoryProvider);
  final created = await repo.createPlayer(request.player);
  ref.invalidate(playersByTeamProvider(request.player.teamId));
  ref.invalidate(playerCountProvider(request.player.teamId));
  return created;
});

/// Create players batch provider
final createPlayersBatchProvider =
    FutureProvider.family<List<Player>, CreatePlayersBatchRequest>((ref, request) async {
  if (request.players.isEmpty) return [];
  final repo = ref.watch(playerRepositoryProvider);
  final created = await repo.createPlayers(request.players);
  ref.invalidate(playersByTeamProvider(request.players.first.teamId));
  ref.invalidate(playerCountProvider(request.players.first.teamId));
  return created;
});

/// Update player provider
final updatePlayerProvider =
    FutureProvider.family<Player, UpdatePlayerRequest>((ref, request) async {
  final repo = ref.watch(playerRepositoryProvider);
  final updated = await repo.updatePlayer(request.player);
  ref.invalidate(playersByTeamProvider(request.player.teamId));
  ref.invalidate(playerByIdProvider(request.player.id));
  return updated;
});

/// Delete player provider
final deletePlayerProvider =
    FutureProvider.family<void, DeletePlayerRequest>((ref, request) async {
  final repo = ref.watch(playerRepositoryProvider);
  await repo.deletePlayer(request.id);
  ref.invalidate(playersByTeamProvider(request.teamId));
  ref.invalidate(playerCountProvider(request.teamId));
});

