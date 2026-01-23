import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_profile.dart';
import '../core/utils/app_logger.dart';
import 'repository_providers.dart';
import 'auth_providers.dart';

/// User profile repository provider
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UserProfileRepository(client);
});

/// Current user profile provider - refreshes when auth state changes
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Watch auth state to refresh when user logs in/out
  final authState = ref.watch(authStateProvider);
  final isAuthenticated = authState.value != null;
  
  if (!isAuthenticated) {
    return null;
  }
  
  final repo = ref.watch(userProfileRepositoryProvider);
  try {
    return await repo.getCurrentProfile();
  } catch (e) {
    AppLogger.error('Error loading profile', e);
    return null;
  }
});

/// Is user approved provider
final isUserApprovedProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile?.isApproved ?? false,
    orElse: () => false,
  );
});

/// Is user admin provider
final isUserAdminProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile?.isAdmin ?? false,
    orElse: () => false,
  );
});

/// Pending users provider (admin only)
final pendingUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(userProfileRepositoryProvider);
  try {
    return await repo.getPendingUsers();
  } catch (e) {
    AppLogger.error('Error loading pending users', e);
    return [];
  }
});

/// All users provider (admin only)
final allUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(userProfileRepositoryProvider);
  try {
    return await repo.getAllUsers();
  } catch (e) {
    AppLogger.error('Error loading all users', e);
    return [];
  }
});

/// Approve user provider
final approveUserProvider = FutureProvider.family<Map<String, dynamic>, ({String userId, String role})>((ref, params) async {
  final repo = ref.watch(userProfileRepositoryProvider);
  final result = await repo.approveUser(params.userId, role: params.role);
  // Invalidate user lists after approval
  ref.invalidate(pendingUsersProvider);
  ref.invalidate(allUsersProvider);
  return result;
});

/// Reject user provider
final rejectUserProvider = FutureProvider.family<Map<String, dynamic>, ({String userId, String? reason})>((ref, params) async {
  final repo = ref.watch(userProfileRepositoryProvider);
  final result = await repo.rejectUser(params.userId, reason: params.reason);
  ref.invalidate(pendingUsersProvider);
  ref.invalidate(allUsersProvider);
  return result;
});
