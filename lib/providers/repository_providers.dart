import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/datasources/datasources.dart';
import '../data/repositories/repositories.dart';

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Organisation repository provider
final organisationRepositoryProvider = Provider<OrganisationRepository>((ref) {
  return SupabaseOrganisationRepository(ref.watch(supabaseClientProvider));
});

/// Tournament repository provider
final tournamentRepositoryProvider = Provider<TournamentRepository>((ref) {
  return SupabaseTournamentRepository(ref.watch(supabaseClientProvider));
});

/// Team repository provider
final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return SupabaseTeamRepository(ref.watch(supabaseClientProvider));
});

/// Player repository provider
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return SupabasePlayerRepository(ref.watch(supabaseClientProvider));
});

/// Match repository provider
final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return SupabaseMatchRepository(ref.watch(supabaseClientProvider));
});

/// Standing repository provider
final standingRepositoryProvider = Provider<StandingRepository>((ref) {
  return SupabaseStandingRepository(ref.watch(supabaseClientProvider));
});
