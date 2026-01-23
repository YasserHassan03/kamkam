import '../models/organisation.dart';

/// Repository interface for Organisation data operations
/// 
/// This abstraction allows for easy testing and swapping implementations
/// (e.g., Supabase, mock, local cache)
abstract class OrganisationRepository {
  /// Get all public organisations
  Future<List<Organisation>> getPublicOrganisations();

  /// Get organisations owned by a specific user
  Future<List<Organisation>> getOrganisationsByOwner(String ownerId);

  /// Get a single organisation by ID
  Future<Organisation?> getOrganisationById(String id);

  /// Create a new organisation
  Future<Organisation> createOrganisation(Organisation organisation);

  /// Update an existing organisation
  Future<Organisation> updateOrganisation(Organisation organisation);

  /// Delete an organisation
  Future<void> deleteOrganisation(String id);

  /// Search organisations by name
  Future<List<Organisation>> searchOrganisations(String query);
}
