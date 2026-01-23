import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/user_profile_providers.dart';

// Import screens
import '../../ui/screens/public/home_screen.dart';
import '../../ui/screens/public/tournament_detail_screen.dart';
import '../../ui/screens/public/standings_screen.dart';
import '../../ui/screens/public/fixtures_screen.dart';
import '../../ui/screens/public/results_screen.dart';
import '../../ui/screens/auth/login_screen.dart';
import '../../ui/screens/auth/register_screen.dart';
import '../../ui/screens/auth/pending_approval_screen.dart';
import '../../ui/screens/admin/dashboard_screen.dart';
import '../../ui/screens/admin/organisation_form_screen.dart';
import '../../ui/screens/admin/tournament_form_screen.dart';
import '../../ui/screens/admin/tournament_admin_screen.dart';
import '../../ui/screens/admin/team_form_screen.dart';
import '../../ui/screens/admin/player_list_screen.dart';
import '../../ui/screens/admin/fixture_form_screen.dart';
import '../../ui/screens/admin/enter_result_screen.dart';
import '../../ui/screens/admin/user_management_screen.dart';

/// App router configuration using GoRouter
/// 
/// Route structure:
/// - Public routes: Accessible without authentication
/// - Auth routes: Login/Register screens
/// - Admin routes: Require authentication AND approval
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false, // Set to true for debugging
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
      final authLoading = authState.isLoading;

      final currentPath = state.matchedLocation;
      final isAuthRoute = currentPath.startsWith('/login') || currentPath.startsWith('/register');
      final isAdminRoute = currentPath.startsWith('/admin');
      final isPendingRoute = currentPath == '/pending-approval';
      final isUserManagementRoute = currentPath == '/admin/users';
      final isPublicRoute = currentPath == '/' || currentPath.startsWith('/tournament/');

      // Get user profile info
      final profileLoading = userProfileAsync.isLoading;
      final userProfile = userProfileAsync.value;
      final hasProfile = userProfile != null;
      final isPending = userProfile?.isPending ?? false;
      final isRejected = userProfile?.isRejected ?? false;
      final isAdmin = userProfile?.isAdmin ?? false;
      final isApproved = userProfile?.isApproved ?? false;

      // Don't redirect while auth or profile is loading
      if (authLoading) {
        return null;
      }

      // 1. Not authenticated -> can access public and auth routes only
      if (!isAuthenticated) {
        if (isAdminRoute || isPendingRoute) {
          return '/login?redirect=$currentPath';
        }
        return null; // Allow public and auth routes
      }

      // === User IS authenticated from here ===

      // 2. Profile still loading -> don't redirect yet, stay on current page
      if (profileLoading) {
        return null;
      }

      // 3. Authenticated with pending/rejected profile -> pending screen
      if (hasProfile && (isPending || isRejected)) {
        if (isPendingRoute || isPublicRoute) {
          return null; // Already on pending or public page
        }
        return '/pending-approval';
      }

      // 4. Authenticated and approved (or no profile yet) on auth route -> admin
      if (isAuthRoute) {
        if (hasProfile && isApproved) {
          return '/admin';
        }
        if (hasProfile && (isPending || isRejected)) {
          return '/pending-approval';
        }
        // No profile yet but authenticated - wait for profile to load
        // or go to admin (profile will be created)
        return '/admin';
      }

      // 5. On pending route but approved -> admin
      if (isPendingRoute && isApproved) {
        return '/admin';
      }

      // 6. Only admins can access user management
      if (isUserManagementRoute && !isAdmin) {
        return '/admin';
      }

      return null;
    },
    routes: [
      // ============ Public Routes ============
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        name: 'pendingApproval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/tournament/:id',
        name: 'tournamentDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TournamentDetailScreen(tournamentId: id);
        },
        routes: [
          GoRoute(
            path: 'standings',
            name: 'standings',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StandingsScreen(tournamentId: id);
            },
          ),
          GoRoute(
            path: 'fixtures',
            name: 'fixtures',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return FixturesScreen(tournamentId: id);
            },
          ),
          GoRoute(
            path: 'results',
            name: 'results',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ResultsScreen(tournamentId: id);
            },
          ),
        ],
      ),

      // ============ Auth Routes ============
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return LoginScreen(redirectTo: redirect);
        },
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ============ Admin Routes ============
      GoRoute(
        path: '/admin',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      
      // User management (admin only)
      GoRoute(
        path: '/admin/users',
        name: 'userManagement',
        builder: (context, state) => const UserManagementScreen(),
      ),
      
      // Organisation routes - redirect list to dashboard
      GoRoute(
        path: '/admin/organisations',
        name: 'organisations',
        redirect: (context, state) => '/admin',
      ),
      GoRoute(
        path: '/admin/organisations/new',
        name: 'createOrganisation',
        builder: (context, state) => const OrganisationFormScreen(),
      ),
      GoRoute(
        path: '/admin/organisations/:orgId',
        name: 'editOrganisation',
        builder: (context, state) {
          final orgId = state.pathParameters['orgId']!;
          return OrganisationFormScreen(organisationId: orgId);
        },
      ),

      // Tournament routes - redirect list to dashboard
      GoRoute(
        path: '/admin/tournaments',
        name: 'tournaments',
        redirect: (context, state) => '/admin',
      ),
      GoRoute(
        path: '/admin/tournaments/new',
        name: 'createTournament',
        builder: (context, state) => const TournamentFormScreen(),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId',
        name: 'tournamentAdmin',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return TournamentAdminScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/edit',
        name: 'editTournament',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return TournamentFormScreen(tournamentId: tournamentId);
        },
      ),

      // Team routes
      GoRoute(
        path: '/admin/tournaments/:tournamentId/teams/new',
        name: 'createTeam',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return TeamFormScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/teams/:teamId',
        name: 'editTeam',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          final teamId = state.pathParameters['teamId']!;
          return TeamFormScreen(tournamentId: tournamentId, teamId: teamId);
        },
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/teams/:teamId/players',
        name: 'teamPlayers',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          final teamId = state.pathParameters['teamId']!;
          return PlayerListScreen(tournamentId: tournamentId, teamId: teamId);
        },
      ),

      // Fixture routes
      GoRoute(
        path: '/admin/tournaments/:tournamentId/fixtures/new',
        name: 'createFixture',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return FixtureFormScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/fixtures/:matchId',
        name: 'editFixture',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          final matchId = state.pathParameters['matchId']!;
          return FixtureFormScreen(tournamentId: tournamentId, matchId: matchId);
        },
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/matches/:matchId/result',
        name: 'enterResult',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          final matchId = state.pathParameters['matchId']!;
          return EnterResultScreen(tournamentId: tournamentId, matchId: matchId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'The requested page does not exist',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
