import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/tournament_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// List of tournaments for admin management
class TournamentListScreen extends ConsumerWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(activeTournamentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeTournamentsProvider);
        },
        child: tournamentsAsync.when(
          data: (tournaments) {
            if (tournaments.isEmpty) {
              return Center(
                child: EmptyStateWidget(
                  icon: Icons.emoji_events,
                  title: 'No Tournaments',
                  subtitle: 'Create your first tournament to get started',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/admin/tournaments/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Tournament'),
                  ),
                ),
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => context.push('/admin/tournaments/${tournament.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tournament.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _StatusChip(status: tournament.status.name),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Season ${tournament.seasonYear}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateRange(tournament.startDate, tournament.endDate),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.groups,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${tournament.rules.rounds} rounds',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const LoadingWidget(),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(activeTournamentsProvider),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/tournaments/new'),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/admin');
              break;
            case 1:
              context.go('/admin/organisations');
              break;
            case 2:
              break; // Already on tournaments
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

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return 'Dates TBD';
    
    final startStr = '${start.day}/${start.month}/${start.year}';
    if (end == null) return 'From $startStr';
    
    final endStr = '${end.day}/${end.month}/${end.year}';
    return '$startStr - $endStr';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'draft':
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurface;
        label = 'Draft';
        break;
      case 'registration':
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue;
        label = 'Registration';
        break;
      case 'active':
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green;
        label = 'Active';
        break;
      case 'completed':
        backgroundColor = Colors.purple.withValues(alpha: 0.2);
        textColor = Colors.purple;
        label = 'Completed';
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red;
        label = 'Cancelled';
        break;
      default:
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurface;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
