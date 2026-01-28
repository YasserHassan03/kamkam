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
import '../../ui/screens/public/golden_boot_screen.dart';
import '../../ui/screens/auth/login_screen.dart';
import '../../ui/screens/auth/register_screen.dart';
import '../../ui/screens/auth/pending_approval_screen.dart';
import '../../ui/screens/admin/dashboard_screen.dart';
import '../../ui/screens/admin/organisation_form_screen.dart';
import '../../ui/screens/admin/tournament_form_screen.dart';
import '../../ui/screens/admin/tournament_admin_screen.dart';
import '../../ui/screens/admin/tournament_management_screen.dart';
import '../../ui/screens/admin/team_form_screen.dart';
import '../../ui/screens/admin/player_list_screen.dart';
import '../../ui/screens/admin/fixture_form_screen.dart';
import '../../ui/screens/admin/enter_result_screen.dart';
import '../../ui/screens/admin/user_management_screen.dart';
import '../../ui/screens/admin/live_match_control_screen.dart';

/// Global navigator key for showing dialogs that persist across route changes
final globalNavigatorKey = GlobalKey<NavigatorState>();

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
    navigatorKey: globalNavigatorKey,
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
      // This prevents redirects during login attempts (including failed logins)
      if (authLoading) {
        return null;
      }
      
      // If we're on login/register and not authenticated, ALWAYS stay there
      // This prevents redirects when login fails
      if (isAuthRoute && !isAuthenticated) {
        return null;
      }

      // 1. Not authenticated -> can access public and auth routes only
      if (!isAuthenticated) {
        if (isAdminRoute || isPendingRoute) {
          // Redirect to home (not login) - cleaner UX for sign-out
          return '/';
        }
        // CRITICAL: If already on login/register, ALWAYS stay there (don't redirect away)
        // This prevents redirects when login fails
        if (isAuthRoute) {
          return null; // Stay on login/register page
        }
        return null; // Allow public and auth routes
      }

      // === User IS authenticated from here ===

      // 2. Profile still loading -> don't redirect yet, stay on current page
      if (profileLoading) {
        return null;
      }

      // 3. NO PROFILE EXISTS - wait a bit for profile to load, or show pending screen
      if (!hasProfile) {
        // Profile might still be loading - wait a bit more
        if (profileLoading) {
          return null; // Wait for profile to load
        }
        // Profile doesn't exist - redirect to pending approval screen
        // This handles cases where profile creation is delayed
        // The pending screen will show an appropriate message
        if (!isPendingRoute) {
          return '/pending-approval';
        }
        return null; // Already on pending route
      }

      // 4. Authenticated with pending/rejected profile -> pending screen
      if (isPending || isRejected) {
        if (isPendingRoute) {
          return null; // Already on pending page
        }
        if (isPublicRoute) {
          // Allow viewing public pages but show a banner or redirect after
          return null;
        }
        // Redirect to pending approval screen
        return '/pending-approval';
      }

      // 5. Authenticated on auth route -> redirect based on approval status
      if (isAuthRoute) {
        if (isPending || isRejected) {
          return '/pending-approval';
        }
        if (isApproved) {
          return '/admin';
        }
        // Fallback
        return '/pending-approval';
      }

      // 6. On pending route but approved -> admin
      if (isPendingRoute && isApproved) {
        return '/admin';
      }

      // 7. Only admins can access user management
      if (isUserManagementRoute && !isAdmin) {
        return '/admin';
      }

      // 8. If authenticated and approved, allow access to admin routes
      if (isAdminRoute && !isApproved) {
        return '/pending-approval';
      }

      return null;
    },
    routes: [
      // ============ Public Routes ============
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
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
            path: 'golden-boot',
            name: 'goldenBoot',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return GoldenBootScreen(tournamentId: id);
            },
          ),
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
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
        path: '/admin/tournaments/manage',
        name: 'tournamentManagement',
        builder: (context, state) => const TournamentManagementScreen(),
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
      GoRoute(
        path: '/admin/live-match/:matchId',
        name: 'liveMatchControl',
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;
          return LiveMatchControlScreen(matchId: matchId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The requested page does not exist',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
