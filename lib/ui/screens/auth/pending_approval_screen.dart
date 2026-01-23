import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/user_profile_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Screen shown to users who are awaiting approval
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(currentUserProfileProvider),
            tooltip: 'Check status',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/');
              }
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            // Profile doesn't exist - show pending approval message
            // This handles cases where profile creation is delayed or failed
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Awaiting Approval',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your account is being set up. Please wait for an administrator to approve your account.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(currentUserProfileProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Status'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (profile.isRejected) {
            return _buildRejectedView(context, profile.rejectionReason);
          }

          if (profile.isApproved) {
            // User got approved, redirect to admin
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/admin');
            });
            return const LoadingWidget(message: 'Redirecting...');
          }

          return _buildPendingView(context, ref);
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
      ),
    );
  }

  Widget _buildPendingView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Awaiting Approval',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your account is pending approval from an administrator.\n\n'
              'You\'ll be able to create and manage tournaments once your account is approved.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(currentUserProfileProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Check Status'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Browse Public Tournaments'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView(BuildContext context, String? reason) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.block_rounded,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your organiser application has been rejected.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Reason:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(reason, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Browse Public Tournaments'),
            ),
          ],
        ),
      ),
    );
  }
}
