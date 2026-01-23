import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';
import 'repository_providers.dart';

/// Current authenticated user provider
final currentUserProvider = Provider<AuthUser?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.currentUser;
});

/// Auth state stream provider
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// Auth state notifier for handling auth actions
class AuthNotifier extends Notifier<AsyncValue<AuthUser?>> {
  late AuthRepository _authRepository;

  @override
  AsyncValue<AuthUser?> build() {
    _authRepository = ref.watch(authRepositoryProvider);
    final user = _authRepository.currentUser;
    
    // Listen to auth state changes
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        state = AsyncValue.data(user);
      });
    });
    
    return AsyncValue.data(user);
  }

  Future<Either<String, AuthUser>> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    final result = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );

    if (result.success && result.user != null) {
      state = AsyncValue.data(result.user);
      return Right(result.user!);
    } else {
      final error = result.error ?? 'Sign in failed';
      state = AsyncValue.error(error, StackTrace.current);
      return Left(error);
    }
  }

  Future<Either<String, AuthUser>> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    final result = await _authRepository.signUpWithEmail(
      email: email,
      password: password,
    );

    if (result.success && result.user != null) {
      state = AsyncValue.data(result.user);
      return Right(result.user!);
    } else {
      final error = result.error ?? 'Sign up failed';
      state = AsyncValue.error(error, StackTrace.current);
      return Left(error);
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const AsyncValue.data(null);
  }

  Future<Either<String, void>> sendPasswordReset(String email) async {
    final result = await _authRepository.sendPasswordResetEmail(email);
    if (result.success) {
      return const Right(null);
    }
    return Left(result.error ?? 'Failed to send reset email');
  }
}

/// Auth notifier provider
final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>(() {
  return AuthNotifier();
});

/// Simple Either type for error handling
abstract class Either<L, R> {
  const Either();
  
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight);
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);
  
  @override
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) {
    return onLeft(value);
  }
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);
  
  @override
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) {
    return onRight(value);
  }
}
