/// Application-wide constants
/// 
/// Contains configuration values, default settings, and magic numbers
/// that are used throughout the application.

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Kam Kam';
  static const String appVersion = '1.0.0';

  // Supabase Configuration
  // TODO: Replace with your actual Supabase credentials
  static const String supabaseUrl = 'https://zpgkejmnvmaesifxdkhx.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpwZ2tlam1udm1hZXNpZnhka2h4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxNjg5MTEsImV4cCI6MjA4NDc0NDkxMX0.QV1fnnt7WB9WPcqduf-ZdC7oYzGTG7ISb-tbQcoCvic';
  // Default Tournament Rules
  static const int defaultPointsForWin = 3;
  static const int defaultPointsForDraw = 1;
  static const int defaultPointsForLoss = 0;
  static const int defaultRounds = 1; // Single round-robin

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Fixtures
  static const int defaultDaysBetweenMatchdays = 7;

  // Form Results (for standings display)
  static const int formResultsCount = 5;

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 5);

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Validation
  static const int minTeamNameLength = 2;
  static const int maxTeamNameLength = 50;
  static const int minOrgNameLength = 3;
  static const int maxOrgNameLength = 100;
  static const int shortNameMaxLength = 5;
}

/// Route paths for navigation
class AppRoutes {
  AppRoutes._();

  // Public Routes
  static const String home = '/';
  static const String tournamentDetails = '/tournament/:id';
  static const String standings = '/tournament/:id/standings';
  static const String fixtures = '/tournament/:id/fixtures';
  static const String results = '/tournament/:id/results';

  // Auth Routes
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Admin Routes
  static const String dashboard = '/admin';
  static const String organisations = '/admin/organisations';
  static const String organisationDetails = '/admin/organisation/:id';
  static const String createOrganisation = '/admin/organisation/new';
  static const String editOrganisation = '/admin/organisation/:id/edit';
  
  static const String tournaments = '/admin/organisation/:orgId/tournaments';
  static const String tournamentAdmin = '/admin/tournament/:id';
  static const String createTournament = '/admin/organisation/:orgId/tournament/new';
  static const String editTournament = '/admin/tournament/:id/edit';
  
  static const String teams = '/admin/tournament/:tournamentId/teams';
  static const String createTeam = '/admin/tournament/:tournamentId/team/new';
  static const String editTeam = '/admin/team/:id/edit';
  static const String teamPlayers = '/admin/team/:id/players';
  
  static const String fixturesAdmin = '/admin/tournament/:tournamentId/fixtures';
  static const String createFixture = '/admin/tournament/:tournamentId/fixture/new';
  static const String editMatch = '/admin/match/:id/edit';
  static const String enterResult = '/admin/match/:id/result';
}

/// Database table names
class DbTables {
  DbTables._();

  static const String organisations = 'organisations';
  static const String tournaments = 'tournaments';
  static const String teams = 'teams';
  static const String players = 'players';
  static const String matches = 'matches';
  static const String standings = 'standings';
}

/// RPC function names
class RpcFunctions {
  RpcFunctions._();

  static const String updateMatchResult = 'update_match_result';
  static const String generateRoundRobinFixtures = 'generate_round_robin_fixtures';
  static const String generateGroupKnockoutKnockouts = 'generate_group_knockout_knockouts';
}
