import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/tournament.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/organisation_providers.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/user_profile_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Admin dashboard home screen
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final orgsAsync = ref.watch(myOrganisationsProvider);
    final isAdmin = ref.watch(isUserAdminProvider);
    final pendingUsersAsync = ref.watch(pendingUsersProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // User signed out - show empty scaffold while router redirects
          return const Scaffold(body: SizedBox.shrink());
        }

        // Fetch tournaments created by the logged-in user's organizations
        final myOrgs = orgsAsync.value ?? [];
        final myTournaments = myOrgs.isNotEmpty
            ? ref.watch(tournamentsByOrgProvider(myOrgs.first.id))
            : AsyncValue<List<Tournament>>.data([]);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Dashboard'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Tournament Views',
              onPressed: () => context.go('/'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
                onPressed: () {
                  // Just sign out - router will handle redirect to '/'
                  ref.read(authNotifierProvider.notifier).signOut();
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back!',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authState.value?.email ?? 'Admin',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickActionCard(
                      icon: Icons.business,
                      label: 'New Organisation',
                      onTap: () => context.go('/admin/organisations/new'),
                    ),
                    _QuickActionCard(
                      icon: Icons.emoji_events,
                      label: 'New Tournament',
                      onTap: () => context.go('/admin/tournaments/new'),
                    ),
                    if (isAdmin) ...[
                      _QuickActionCard(
                        icon: Icons.admin_panel_settings,
                        label: 'User Management',
                        badge: pendingUsersAsync.value?.length ?? 0,
                        onTap: () => context.go('/admin/users'),
                      ),
                      _QuickActionCard(
                        icon: Icons.visibility,
                        label: 'Tournament Management',
                        onTap: () => context.go('/admin/tournaments/manage'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Admin: Pending Approvals Section (only for admins)
                if (isAdmin) ...[
                  _PendingApprovalsSection(pendingUsersAsync: pendingUsersAsync),
                  const SizedBox(height: 24),
                ],

                // My Organisations
                Text(
                  'My Organisations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                orgsAsync.when(
                  data: (orgs) {
                    if (orgs.isEmpty) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.add_business),
                          title: const Text('No organisations yet'),
                          subtitle: const Text('Create your first organisation'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.go('/admin/organisations/new'),
                        ),
                      );
                    }
                    final orgList = orgs.take(3).toList();
                    return Column(
                      children: orgList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final org = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(bottom: index < orgList.length - 1 ? 8 : 0),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: org.logoUrl != null
                                ? CircleAvatar(backgroundImage: NetworkImage(org.logoUrl!))
                                : CircleAvatar(child: Text(org.name[0].toUpperCase())),
                              title: Text(org.name),
                              subtitle: Text(org.ownerEmail),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.go('/admin/organisations/${org.id}'),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (e, _) => AppErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(myOrganisationsProvider),
                  ),
                ),
                if (orgsAsync.hasValue && orgsAsync.value!.length > 3) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/admin/organisations'),
                    child: const Text('View all organisations'),
                  ),
                ],
                const SizedBox(height: 24),

                // My Tournaments (combined section)
                Text(
                  'My Tournaments',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                myTournaments.when(
                  data: (tournaments) {
                    if (tournaments.isEmpty) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.add_circle),
                          title: const Text('No tournaments yet'),
                          subtitle: const Text('Create your first tournament'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.go('/admin/tournaments/new'),
                        ),
                      );
                    }
                    return Column(
                      children: tournaments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final tournament = entry.value;
                        // Find the organisation for this tournament to get its logo
                        final org = myOrgs.firstWhere(
                          (o) => o.id == tournament.orgId,
                          orElse: () => myOrgs.first,
                        );
                        return Padding(
                          padding: EdgeInsets.only(bottom: index < tournaments.length - 1 ? 8 : 0),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: org.logoUrl != null
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(org.logoUrl!),
                                  )
                                : CircleAvatar(
                                    backgroundColor: tournament.status == TournamentStatus.draft
                                        ? Theme.of(context).colorScheme.tertiaryContainer
                                        : Theme.of(context).colorScheme.secondaryContainer,
                                    child: Icon(
                                      tournament.status == TournamentStatus.draft
                                          ? Icons.edit_note
                                          : Icons.emoji_events,
                                      color: tournament.status == TournamentStatus.draft
                                          ? Theme.of(context).colorScheme.onTertiaryContainer
                                          : Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                              title: Text(tournament.name),
                              subtitle: Text('${tournament.rules.type.displayName} · ${tournament.status.displayName}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.go('/admin/tournaments/${tournament.id}'),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (e, _) => AppErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(tournamentsByOrgProvider(myOrgs.first.id)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingApprovalsSection extends StatelessWidget {
  final AsyncValue<List<dynamic>> pendingUsersAsync;

  const _PendingApprovalsSection({required this.pendingUsersAsync});

  @override
  Widget build(BuildContext context) {
    return pendingUsersAsync.when(
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Pending Approvals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    users.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.orange.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(Icons.group_add, color: Colors.orange),
                title: Text('${users.length} user(s) waiting for approval'),
                subtitle: const Text('Review and approve new organisers'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => GoRouter.of(context).go('/admin/users'),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
