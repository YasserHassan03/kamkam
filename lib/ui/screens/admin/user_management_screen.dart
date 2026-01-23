import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/user_profile_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Admin screen for managing user approvals
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        actions: [
          // Refresh button for manual refresh
          Consumer(
            builder: (context, ref, _) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(pendingUsersProvider);
                ref.invalidate(allUsersProvider);
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.hourglass_top)),
            Tab(text: 'All Users', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingUsersTab(),
          _AllUsersTab(),
        ],
      ),
    );
  }
}

class _PendingUsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingUsersProvider);

    return pendingAsync.when(
      data: (users) {
        // Double-check: filter to only show pending users (in case RPC returns wrong data)
        final pendingOnly = users.where((u) => u.isPending).toList();
        
        if (pendingOnly.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.check_circle_outline,
            title: 'No Pending Approvals',
            subtitle: 'All users have been reviewed. New signups will appear automatically.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh by invalidating the provider
            ref.invalidate(pendingUsersProvider);
            // Wait a moment for the refresh
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingOnly.length,
            itemBuilder: (context, index) => _UserCard(
              user: pendingOnly[index],
              showActions: true,
            ),
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(pendingUsersProvider),
      ),
    );
  }
}

class _AllUsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.people_outline,
            title: 'No Users',
            subtitle: 'No users have signed up yet',
          );
        }

        // Filter out pending users from "All Users" tab - they should only appear in "Pending" tab
        final nonPendingUsers = users.where((u) => !u.isPending).toList();

        if (nonPendingUsers.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.people_outline,
            title: 'No Approved Users',
            subtitle: 'All users are pending approval',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allUsersProvider);
            ref.invalidate(pendingUsersProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: nonPendingUsers.length,
            itemBuilder: (context, index) => _UserCard(
              user: nonPendingUsers[index],
              showActions: false, // No approve/reject actions in "All Users" tab
              showDelete: true, // Show delete button for admins
            ),
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(allUsersProvider),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserProfile user;
  final bool showActions;
  final bool showDelete;

  const _UserCard({
    required this.user,
    this.showActions = false,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                  child: Text(
                    (user.displayName ?? user.email)[0].toUpperCase(),
                    style: TextStyle(
                      color: _getRoleColor(user.role),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? user.email.split('@').first,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoleChip(role: user.role),
              ],
            ),
            if (user.rejectionReason != null && user.isRejected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user.rejectionReason!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Joined: ${_formatDate(user.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, ref),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _approveUser(context, ref),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            ],
            if (showDelete) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final currentUserId = ref.watch(authStateProvider).value?.id;
                      final isCurrentUser = currentUserId == user.id;
                      
                      if (isCurrentUser) {
                        return const SizedBox.shrink(); // Don't show delete for current user
                      }
                      
                      return OutlinedButton.icon(
                        onPressed: () => _showDeleteUserDialog(context, ref),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete User'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.organiser:
        return Colors.green;
      case UserRole.pending:
        return Colors.orange;
      case UserRole.rejected:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _approveUser(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(approveUserProvider((userId: user.id, role: 'organiser')).future);
    } catch (e) {
      // Error handled silently
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject ${user.email}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Enter rejection reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(rejectUserProvider((
          userId: user.id,
          reason: reasonController.text.isEmpty ? null : reasonController.text,
        )).future);
      } catch (e) {
        // Error handled silently
      }
    }

    reasonController.dispose();
  }

  Future<void> _showDeleteUserDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete "${user.email}"?\n\n'
          'This will permanently delete:\n'
          '• The user profile\n'
          '• All organisations owned by this user\n'
          '• All tournaments owned by this user\n'
          '• All related data (teams, matches, etc.)\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete User'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(deleteUserProvider(user.id).future);
      } catch (e) {
        // Error handled silently
      }
    }
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: _getColor(),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.organiser:
        return Colors.green;
      case UserRole.pending:
        return Colors.orange;
      case UserRole.rejected:
        return Colors.red;
    }
  }
}
