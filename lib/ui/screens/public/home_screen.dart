import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/organisation_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/favourite_providers.dart';
import '../../../data/models/tournament.dart';
import '../../../data/models/organisation.dart';
import '../../../core/constants/enums.dart' as app_enums;
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Modern home screen showing public tournaments
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedOrgId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter tournaments by search query and organisation
  List<Tournament> _filterTournaments(List<Tournament> tournaments) {
    var filtered = tournaments;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) => 
        t.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    if (_selectedOrgId != null) {
      filtered = filtered.where((t) => t.orgId == _selectedOrgId).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(publicTournamentsProvider);
    final organisationsAsync = ref.watch(publicOrganisationsProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final favorites = ref.watch(userFavoriteTournamentIdsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(publicTournamentsProvider);
            ref.invalidate(publicOrganisationsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverToBoxAdapter(
                child: _AppHeader(isAuthenticated: isAuthenticated),
              ),
              
              // Search and Filter Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search tournaments...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 12),
                      
                      // Organisation filter dropdown
                      organisationsAsync.when(
                        data: (organisations) {
                          if (organisations.isEmpty) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedOrgId,
                                hint: const Text('Filter by organiser'),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Organisers'),
                                  ),
                                  ...organisations.map((org) => DropdownMenuItem<String?>(
                                    value: org.id,
                                    child: Row(
                                      children: [
                                        if (org.logoUrl != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundImage: NetworkImage(org.logoUrl!),
                                            ),
                                          ),
                                        Expanded(child: Text(org.name, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  )),
                                ],
                                onChanged: (value) => setState(() => _selectedOrgId = value),
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content
              tournamentsAsync.when(
                data: (tournaments) {
                  final filtered = _filterTournaments(tournaments);
                  
                  if (tournaments.isEmpty) {
                    return SliverFillRemaining(
                      child: _EmptyState(),
                    );
                  }
                  
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('No tournaments match your search', style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                      ),
                    );
                  }

                  return organisationsAsync.when(
                    data: (organisations) => _TournamentContent(
                      tournaments: filtered,
                      organisations: organisations,
                      favorites: favorites,
                    ),
                    loading: () => _TournamentContent(
                      tournaments: filtered,
                      organisations: const [],
                      favorites: favorites,
                    ),
                    error: (e, _) => _TournamentContent(
                      tournaments: filtered,
                      organisations: const [],
                      favorites: favorites,
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: LoadingWidget(),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: AppErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(publicTournamentsProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App header with logo and actions
class _AppHeader extends StatelessWidget {
  final bool isAuthenticated;

  const _AppHeader({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          // Logo and App Name
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.sports_soccer_rounded,
                    size: 26,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Football Tournaments',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          if (isAuthenticated)
            FilledButton.icon(
              onPressed: () => context.go('/admin'),
              icon: const Icon(Icons.dashboard_rounded, size: 18),
              label: const Text('Dashboard'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            )
          else
            FilledButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Login'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state when no tournaments
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Tournaments Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back soon for upcoming competitions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tournament content with sections
class _TournamentContent extends StatelessWidget {
  final List<Tournament> tournaments;
  final List<Organisation> organisations;
  final List<String> favorites;

  const _TournamentContent({
    required this.tournaments,
    required this.organisations,
    required this.favorites,
  });

  @override
  Widget build(BuildContext context) {
    final favoriteTournaments = tournaments
        .where((t) => favorites.contains(t.id))
        .toList();
    
    final otherTournaments = tournaments
        .where((t) => !favorites.contains(t.id))
        .toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        // My Tournaments Section (favorites)
        if (favoriteTournaments.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.favorite_rounded,
            iconColor: AppTheme.errorRed,
            title: 'My Tournaments',
          ),
          ...favoriteTournaments.map((t) => _TournamentCard(
            tournament: t,
            organisations: organisations,
            isFavorite: true,
          )),
          const SizedBox(height: 16),
        ],
        
        // All Tournaments Section
        _SectionHeader(
          icon: Icons.public_rounded,
          iconColor: Theme.of(context).colorScheme.primary,
          title: 'All Tournaments',
        ),
        if (otherTournaments.isEmpty && favoriteTournaments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Center(
              child: Text(
                'No tournaments available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          )
        else
          ...otherTournaments.map((t) => _TournamentCard(
            tournament: t,
            organisations: organisations,
            isFavorite: false,
          )),
        
        const SizedBox(height: 32),
      ]),
    );
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tournament card
class _TournamentCard extends ConsumerWidget {
  final Tournament tournament;
  final List<Organisation> organisations;
  final bool isFavorite;

  const _TournamentCard({
    required this.tournament,
    required this.organisations,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organiserName = _getOrganiserName(tournament, organisations);
    final formatLabel = _getFormatLabel(tournament.format);
    final statusColor = _getStatusColor(tournament.status);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/tournament/${tournament.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFavorite 
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isFavorite ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // Top row: Format badge, Status, Favorite
                        Row(
                          children: [
                            // Format badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                formatLabel,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    tournament.status.displayName,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Favorite button
                            _FavoriteButton(
                              tournamentId: tournament.id,
                              isFavorite: isFavorite,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        
                        // Tournament name
                        Text(
                          tournament.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        
                        // Organiser
                        Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                organiserName,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Bottom row: Venue and Date
                        Row(
                          children: [
                            // Venue
                            if (tournament.venue != null && tournament.venue!.isNotEmpty) ...[
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        tournament.venue!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            // Date
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tournament.startDate != null 
                                      ? _formatDate(tournament.startDate!) 
                                      : 'TBD',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Organisation logo on the right
                  Builder(
                    builder: (context) {
                      final org = organisations.where((o) => o.id == tournament.orgId).firstOrNull;
                      if (org?.logoUrl != null) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              org!.logoUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
            
            // Sponsored by section (only if sponsor logo exists)
            if (tournament.sponsorLogoUrl != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Sponsored by:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          tournament.sponsorLogoUrl!,
                          height: 40,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  String _getOrganiserName(Tournament tournament, List<Organisation> orgs) {
    // 1. Try to find the actual Organisation name first
    final org = orgs.where((o) => o.id == tournament.orgId).firstOrNull;
    if (org != null) return org.name;
    
    // 2. Fallback to owner email (username part) if org not found
    if (tournament.ownerEmail != null && tournament.ownerEmail!.isNotEmpty) {
      final emailName = tournament.ownerEmail!.split('@').first;
      return emailName[0].toUpperCase() + emailName.substring(1);
    }
    
    return 'Unknown Organiser';
  }

  String _getFormatLabel(String format) {
    switch (format) {
      case 'league':
        return 'League';
      case 'knockout':
        return 'Knockout';
      case 'group_knockout':
        return 'Group + Knockout';
      default:
        return format.toUpperCase();
    }
  }

  Color _getStatusColor(app_enums.TournamentStatus status) {
    switch (status) {
      case app_enums.TournamentStatus.active:
        return AppTheme.activeStatus;
      case app_enums.TournamentStatus.completed:
        return AppTheme.completedStatus;
      case app_enums.TournamentStatus.draft:
      default:
        return AppTheme.draftStatus;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Tomorrow';
    if (difference.inDays > 0 && difference.inDays < 7) {
      return 'In ${difference.inDays} days';
    }
    if (difference.inDays < 0 && difference.inDays > -7) {
      return '${-difference.inDays} days ago';
    }
    
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Favorite button with animation
class _FavoriteButton extends ConsumerWidget {
  final String tournamentId;
  final bool isFavorite;

  const _FavoriteButton({
    required this.tournamentId,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(favoriteTournamentsProvider.notifier).toggleFavorite(tournamentId);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              key: ValueKey(isFavorite),
              size: 22,
              color: isFavorite 
                  ? AppTheme.errorRed 
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}
