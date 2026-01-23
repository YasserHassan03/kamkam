import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/organisation.dart';
import '../repositories/organisation_repository.dart';

/// Supabase implementation of OrganisationRepository
class SupabaseOrganisationRepository implements OrganisationRepository {
  final SupabaseClient _client;

  SupabaseOrganisationRepository(this._client);

  @override
  Future<List<Organisation>> getPublicOrganisations() async {
    final response = await _client
        .from(DbTables.organisations)
        .select()
        .eq('visibility', 'public')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Organisation.fromJson(json))
        .toList();
  }

  @override
  Future<List<Organisation>> getOrganisationsByOwner(String ownerId) async {
    final response = await _client
        .from(DbTables.organisations)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Organisation.fromJson(json))
        .toList();
  }

  @override
  Future<Organisation?> getOrganisationById(String id) async {
    final response = await _client
        .from(DbTables.organisations)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Organisation.fromJson(response);
  }

  @override
  Future<Organisation> createOrganisation(Organisation organisation) async {
    final response = await _client
        .from(DbTables.organisations)
        .insert(organisation.toInsertJson())
        .select()
        .single();

    return Organisation.fromJson(response);
  }

  @override
  Future<Organisation> updateOrganisation(Organisation organisation) async {
    final response = await _client
        .from(DbTables.organisations)
        .update({
          'name': organisation.name,
          'description': organisation.description,
          'logo_url': organisation.logoUrl,
          'visibility': organisation.visibility.name,
        })
        .eq('id', organisation.id)
        .select()
        .single();

    return Organisation.fromJson(response);
  }

  @override
  Future<void> deleteOrganisation(String id) async {
    await _client.from(DbTables.organisations).delete().eq('id', id);
  }

  @override
  Future<List<Organisation>> searchOrganisations(String query) async {
    final response = await _client
        .from(DbTables.organisations)
        .select()
        .eq('visibility', 'public')
        .ilike('name', '%$query%')
        .order('name')
        .limit(20);

    return (response as List)
        .map((json) => Organisation.fromJson(json))
        .toList();
  }
}
