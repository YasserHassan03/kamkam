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
import '../../widgets/common/loading_error_widgets.dart';

/// Modern home screen showing public tournaments
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(publicTournamentsProvider);
    final organisationsAsync = ref.watch(publicOrganisationsProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final favorites = ref.watch(userFavoriteTournamentIdsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Icon(
              Icons.sports_soccer_rounded,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(AppConstants.appName),
          ],
        ),
        actions: [
          if (isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Admin Dashboard',
                child: FilledButton.icon(
                  onPressed: () => context.go('/admin'),
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
                  label: const Text('Admin'),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('Login'),
                onPressed: () => context.go('/login'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicTournamentsProvider);
          ref.invalidate(publicOrganisationsProvider);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0F1419),
                      const Color(0xFF1A1F2B).withValues(alpha: 0.5),
                    ]
                  : [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFFAFCFF),
                    ],
            ),
          ),
          child: tournamentsAsync.when(
            data: (tournaments) {
              if (tournaments.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.sports_soccer,
                  title: 'No Tournaments Yet',
                  subtitle: 'Be the first to create a tournament!',
                );
              }

              return organisationsAsync.when(
                data: (organisations) => _TournamentList(
                  tournaments: tournaments,
                  organisations: organisations,
                  favorites: favorites,
                  isAuthenticated: isAuthenticated,
                ),
                loading: () => _TournamentList(
                  tournaments: tournaments,
                  organisations: const [],
                  favorites: favorites,
                  isAuthenticated: isAuthenticated,
                ),
                error: (e, _) => _TournamentList(
                  tournaments: tournaments,
                  organisations: const [],
                  favorites: favorites,
                  isAuthenticated: isAuthenticated,
                ),
              );
            },
            loading: () => const LoadingWidget(),
            error: (e, _) => AppErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(publicTournamentsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentList extends StatelessWidget {
  final List<Tournament> tournaments;
  final List<Organisation> organisations;
  final List<String> favorites;
  final bool isAuthenticated;

  const _TournamentList({
    required this.tournaments,
    required this.organisations,
    required this.favorites,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    // Separate favorite and non-favorite tournaments
    final favoriteTournaments = tournaments
        .where((t) => favorites.contains(t.id))
        .toList();
    
    final otherTournaments = tournaments
        .where((t) => !favorites.contains(t.id))
        .toList();

    // Group non-favorite tournaments by organisation
    final Map<String, List<Tournament>> grouped = {};
    for (final tournament in otherTournaments) {
      // Use org_id to group tournaments, not owner_id
      grouped.putIfAbsent(tournament.orgId, () => []).add(tournament);
    }

    // Create organisation map for quick lookup
    final Map<String, Organisation> orgMap = {
      for (final org in organisations) org.id: org
    };

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // My Tournaments Section (Only if has favorites)
          if (favoriteTournaments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Tournaments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ...favoriteTournaments.map((tournament) {
              // Use org_id to find the organisation, not owner_id
              final org = organisations.firstWhere(
                (o) => o.id == tournament.orgId,
                orElse: () => Organisation(
                  id: '',
                  name: 'Unknown Organisation',
                  ownerId: '',
                  ownerEmail: '',
                  visibility: app_enums.Visibility.public,
                ),
              );
              return _TournamentCard(
                tournament: tournament,
                organiserName: org.name,
                isFavorited: true,
                isAuthenticated: isAuthenticated,
              );
            }),
            const SizedBox(height: 24),
          ],
          
          // All Tournaments Section
          if (otherTournaments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sports_soccer_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'All Tournaments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ...grouped.entries.map((entry) {
              final orgTournaments = entry.value;
              final org = orgMap[entry.key];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            org?.name ?? 'Unknown Organisation',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...orgTournaments.map((tournament) => _TournamentCard(
                    tournament: tournament,
                    organiserName: org?.name ?? 'Unknown Organisation',
                    isAuthenticated: isAuthenticated,
                  )),
                ],
              );
            }),
          ],
          
          // Empty state only if no tournaments at all
          if (tournaments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.sports_soccer,
                  title: 'No Tournaments Yet',
                  subtitle: 'Be the first to create a tournament!',
                ),
              ),
            ),
          
          // Bottom padding
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TournamentCard extends ConsumerWidget {
  final Tournament tournament;
  final String organiserName;
  final bool isFavorited;
  final bool isAuthenticated;

  const _TournamentCard({
    required this.tournament,
    required this.organiserName,
    this.isFavorited = false,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = tournament.status == app_enums.TournamentStatus.active;
    final isFav = ref.watch(isTournamentFavoritedProvider(tournament.id));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: isFav
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
              : isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: (isFav || isActive) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/tournament/${tournament.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Tournament Format Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tournament.rules.type.displayName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Favorite button
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            ref.read(favoriteTournamentsProvider.notifier).toggleFavorite(tournament.id);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isFav
                                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 20,
                              color: isFav
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.play_circle_rounded : Icons.schedule_rounded,
                            size: 14,
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tournament.status.displayName,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Tournament Name
                Text(
                  tournament.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Organiser: $organiserName',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Venue row (if venue exists)
                if (tournament.venue != null && tournament.venue!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tournament.venue!,
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                // Date row (always shown)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tournament.startDate != null ? _formatDate(tournament.startDate!) : 'TBD',
                        style: Theme.of(context).textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Tomorrow';
    if (difference.inDays < 7) return 'In ${difference.inDays} days';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}

