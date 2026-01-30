import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/organisation_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// List of organisations managed by the user
class OrganisationListScreen extends ConsumerWidget {
  const OrganisationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(myOrganisationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organisations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myOrganisationsProvider);
        },
        child: orgsAsync.when(
          data: (orgs) {
            if (orgs.isEmpty) {
              return Center(
                child: EmptyStateWidget(
                  icon: Icons.business,
                  title: 'No Organisations',
                  subtitle: 'Create your first organisation to get started',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/admin/organisations/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Organisation'),
                  ),
                ),
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: orgs.length,
              itemBuilder: (context, index) {
                final org = orgs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: org.logoUrl != null
                      ? CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(org.logoUrl!),
                        )
                      : CircleAvatar(
                          radius: 28,
                          child: Text(
                            org.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                    title: Text(
                      org.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (org.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            org.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(org.ownerEmail),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/admin/organisations/${org.id}'),
                  ),
                );
              },
            );
          },
          loading: () => const LoadingWidget(),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(myOrganisationsProvider),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/organisations/new'),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/admin');
              break;
            case 1:
              break; // Already on organisations
            case 2:
              context.go('/admin/tournaments');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Organisations',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Tournaments',
          ),
        ],
      ),
    );
  }
}
