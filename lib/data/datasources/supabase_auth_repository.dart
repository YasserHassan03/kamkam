import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../repositories/auth_repository.dart';
import '../../core/utils/app_logger.dart';

/// Supabase implementation of AuthRepository
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? AuthUser.fromSupabaseUser(user) : null;
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user != null ? AuthUser.fromSupabaseUser(user) : null;
    });
  }

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        return AuthResult.success(AuthUser.fromSupabaseUser(response.user!));
      }
      
      return const AuthResult.failure('Sign in failed');
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Sign out immediately - user needs approval before they can use the app
        // The database trigger will create their profile with 'pending' status
        await _client.auth.signOut();
        
        return AuthResult.success(AuthUser.fromSupabaseUser(response.user!));
      }
      
      // Check if user was created but needs email confirmation
      if (response.session == null && response.user == null) {
        return const AuthResult.failure(
          'Check your email for confirmation link, or email confirmation may be disabled in Supabase'
        );
      }
      
      return const AuthResult.failure('Sign up failed - no user returned');
    } on AuthException catch (e) {
      return AuthResult.failure('Auth error: ${e.message}');
    } catch (e) {
      return AuthResult.failure('Error: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  @override
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }
}
