import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/organisation.dart';
import 'repository_providers.dart';
import 'auth_providers.dart';

/// Public organisations provider
final publicOrganisationsProvider = FutureProvider<List<Organisation>>((ref) async {
  final repo = ref.watch(organisationRepositoryProvider);
  return await repo.getPublicOrganisations();
});

/// User's organisations provider (requires auth)
final myOrganisationsProvider = FutureProvider<List<Organisation>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final repo = ref.watch(organisationRepositoryProvider);

  return authState.maybeWhen(
    data: (user) async {
      if (user == null) return [];
      return await repo.getOrganisationsByOwner(user.id);
    },
    orElse: () => [],
  );
});

/// Single organisation by ID provider
final organisationByIdProvider =
    FutureProvider.family<Organisation?, String>((ref, id) async {
  final repo = ref.watch(organisationRepositoryProvider);
  return await repo.getOrganisationById(id);
});

/// Organisation search provider
final organisationSearchProvider =
    FutureProvider.family<List<Organisation>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repo = ref.watch(organisationRepositoryProvider);
  return await repo.searchOrganisations(query);
});

/// Create organisation provider
final createOrganisationProvider =
    FutureProvider.family<Organisation, Organisation>((ref, org) async {
  final repo = ref.watch(organisationRepositoryProvider);
  final created = await repo.createOrganisation(org);
  ref.invalidate(myOrganisationsProvider);
  ref.invalidate(publicOrganisationsProvider);
  return created;
});

/// Update organisation provider
final updateOrganisationProvider =
    FutureProvider.family<Organisation, Organisation>((ref, org) async {
  final repo = ref.watch(organisationRepositoryProvider);
  final updated = await repo.updateOrganisation(org);
  ref.invalidate(myOrganisationsProvider);
  ref.invalidate(publicOrganisationsProvider);
  ref.invalidate(organisationByIdProvider(org.id));
  return updated;
});

/// Delete organisation provider
final deleteOrganisationProvider =
    FutureProvider.family<void, String>((ref, id) async {
  final repo = ref.watch(organisationRepositoryProvider);
  await repo.deleteOrganisation(id);
  ref.invalidate(myOrganisationsProvider);
  ref.invalidate(publicOrganisationsProvider);
});
