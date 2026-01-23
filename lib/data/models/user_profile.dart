import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/app_logger.dart';

/// User profile with approval status
class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'pending'),
      rejectionReason: json['rejection_reason'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'role': role.name,
    'rejection_reason': rejectionReason,
    'approved_by': approvedBy,
    'approved_at': approvedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  bool get isPending => role == UserRole.pending;
  bool get isApproved => role == UserRole.organiser || role == UserRole.admin;
  bool get isAdmin => role == UserRole.admin;
  bool get isRejected => role == UserRole.rejected;
}

/// User role enum
enum UserRole {
  pending,
  organiser,
  admin,
  rejected;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'organiser':
        return UserRole.organiser;
      case 'rejected':
        return UserRole.rejected;
      default:
        return UserRole.pending;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.pending:
        return 'Pending Approval';
      case UserRole.organiser:
        return 'Organiser';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.rejected:
        return 'Rejected';
    }
  }
}

/// Repository for user profile operations
class UserProfileRepository {
  final SupabaseClient _client;

  UserProfileRepository(this._client);

  /// Get current user's profile
  Future<UserProfile?> getCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // Profile doesn't exist - trigger should have created it
        // If not, user needs to contact admin
        AppLogger.debug('No profile found for user $userId');
        return null;
      }
      return UserProfile.fromJson(response);
    } catch (e) {
      AppLogger.error('Error getting user profile', e);
      return null;
    }
  }

  /// Get approval status using RPC
  Future<Map<String, dynamic>> getApprovalStatus() async {
    try {
      final response = await _client.rpc('get_my_approval_status');
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'pending', 'error': e.toString()};
    }
  }

  /// Update display name
  Future<void> updateDisplayName(String displayName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _client
        .from('user_profiles')
        .update({'display_name': displayName})
        .eq('id', userId);
  }

  /// Get all pending users (admin only)
  Future<List<UserProfile>> getPendingUsers() async {
    final response = await _client.rpc('get_pending_users');
    return (response as List)
        .map((json) => UserProfile.fromJson(json))
        .toList();
  }

  /// Get all users (admin only) - uses RPC to bypass RLS
  Future<List<UserProfile>> getAllUsers() async {
    final response = await _client.rpc('get_all_users');
    return (response as List)
        .map((json) => UserProfile.fromJson(json))
        .toList();
  }

  /// Approve a user (admin only)
  Future<Map<String, dynamic>> approveUser(String userId, {String role = 'organiser'}) async {
    final response = await _client.rpc('approve_user', params: {
      'p_user_id': userId,
      'p_role': role,
    });
    return response as Map<String, dynamic>;
  }

  /// Reject a user (admin only)
  Future<Map<String, dynamic>> rejectUser(String userId, {String? reason}) async {
    final response = await _client.rpc('reject_user', params: {
      'p_user_id': userId,
      'p_reason': reason,
    });
    return response as Map<String, dynamic>;
  }
}
