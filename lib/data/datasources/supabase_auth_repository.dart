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
        // Check if user has a profile - wait a bit for trigger to create it if needed
        Map<String, dynamic>? profileResponse;
        for (int attempt = 0; attempt < 5; attempt++) {
          await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
          
          try {
            profileResponse = await _client
                .from('user_profiles')
                .select()
                .eq('id', response.user!.id)
                .maybeSingle() as Map<String, dynamic>?;
            
            if (profileResponse != null) {
              break; // Profile found, exit retry loop
            }
          } catch (e) {
            // If it's a permission error, might be RLS - try again
            if (attempt < 4) continue;
          }
        }
        
        // If still no profile after retries, allow sign-in anyway
        // The router will handle showing appropriate message
        // This allows the app to work even if profile creation is delayed
        if (profileResponse == null) {
          // Profile doesn't exist yet - but allow sign-in
          // Router will detect no profile and handle appropriately
          // This is better than blocking the user completely
          return AuthResult.success(AuthUser.fromSupabaseUser(response.user!));
        }
        
        // Profile exists - allow sign-in for all users (including pending/rejected)
        // The router will handle redirecting them to the appropriate screen
        // This allows pending users to see the pending approval screen
        // and rejected users to see the rejection screen
        
        // User is authenticated - allow sign-in
        // Router will check role and redirect accordingly
        return AuthResult.success(AuthUser.fromSupabaseUser(response.user!));
      }
      
      // Ensure user is signed out on failure
      await _client.auth.signOut();
      return const AuthResult.failure('Sign in failed - invalid credentials');
    } on AuthException catch (e) {
      // Ensure user is signed out on error
      await _client.auth.signOut();
      
      // Provide better error messages for common cases
      final errorMsg = e.message.toLowerCase();
      if (errorMsg.contains('invalid login') || 
          errorMsg.contains('invalid credentials') ||
          errorMsg.contains('email not confirmed')) {
        return AuthResult.failure('Invalid email or password. Please check your credentials and try again.');
      } else if (errorMsg.contains('user not found') || 
                 errorMsg.contains('no user found')) {
        return AuthResult.failure('No account found with this email. Please sign up first.');
      } else if (errorMsg.contains('wrong password') ||
                 errorMsg.contains('incorrect password')) {
        return AuthResult.failure('Incorrect password. Please try again.');
      }
      return AuthResult.failure(e.message);
    } catch (e) {
      // Ensure user is signed out on any error
      try {
        await _client.auth.signOut();
      } catch (_) {
        // Ignore sign out errors
      }
      return AuthResult.failure('Sign in failed: ${e.toString()}');
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
        // Wait for the database trigger to create the profile
        // Try multiple times with increasing delays in case trigger is slow
        Map<String, dynamic>? profileData;
        for (int attempt = 0; attempt < 5; attempt++) {
          await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
          
          try {
            final profileResponse = await _client
                .from('user_profiles')
                .select()
                .eq('id', response.user!.id)
                .maybeSingle();
            
            if (profileResponse != null) {
              profileData = profileResponse as Map<String, dynamic>;
              break;
            }
          } catch (e) {
            // Continue trying
            AppLogger.debug('Profile check attempt ${attempt + 1} failed: $e');
          }
        }
        
        if (profileData == null) {
          // Trigger didn't create profile - this is a problem
          // The trigger should have fired automatically
          await _client.auth.signOut();
          AppLogger.error(
            'Profile creation failed after sign-up',
            'User ID: ${response.user!.id}, Email: $email'
          );
          return AuthResult.failure(
            'Account created but profile setup failed. '
            'This may be a database configuration issue. '
            'Please contact an administrator with your email: $email'
          );
        }
        
        // Keep user signed in so they can see the pending approval screen
        // The router will redirect them to /pending-approval and block admin access
        
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
