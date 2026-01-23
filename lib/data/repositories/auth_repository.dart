import 'package:supabase_flutter/supabase_flutter.dart';

/// User credentials for authentication
class AuthUser {
  final String id;
  final String email;
  final DateTime? createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    this.createdAt,
  });

  factory AuthUser.fromSupabaseUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }
}

/// Result of authentication operations
class AuthResult {
  final bool success;
  final AuthUser? user;
  final String? error;

  const AuthResult({
    required this.success,
    this.user,
    this.error,
  });

  const AuthResult.success(this.user)
      : success = true,
        error = null;

  const AuthResult.failure(this.error)
      : success = false,
        user = null;
}

/// Repository interface for Authentication operations
abstract class AuthRepository {
  /// Get current authenticated user
  AuthUser? get currentUser;

  /// Stream of authentication state changes
  Stream<AuthUser?> get authStateChanges;

  /// Check if user is currently authenticated
  bool get isAuthenticated;

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Sign out
  Future<void> signOut();

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email);

  /// Update password
  Future<AuthResult> updatePassword(String newPassword);
}
