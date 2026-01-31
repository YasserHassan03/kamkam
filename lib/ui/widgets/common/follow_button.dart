import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/notification_providers.dart';

class FollowButton extends ConsumerWidget {
  final String? tournamentId;
  final String? teamId;
  final double? size;
  final Color? color;

  const FollowButton({
    super.key,
    this.tournamentId,
    this.teamId,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubscribedAsync = ref.watch(isSubscribedProvider((
      tournamentId: tournamentId,
      teamId: teamId,
    )));

    return isSubscribedAsync.when(
      data: (isSubscribed) => IconButton(
        icon: Icon(
          isSubscribed ? Icons.notifications_active : Icons.notifications_none_outlined,
          color: isSubscribed ? (color ?? Colors.amber) : null,
          size: size,
        ),
        onPressed: () async {
          final result = await ref.read(toggleSubscriptionProvider((
            tournamentId: tournamentId,
            teamId: teamId,
          )).future);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result 
                  ? 'Notifications turned on' 
                  : 'Notifications turned off'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        tooltip: isSubscribed ? 'Unfollow' : 'Follow',
      ),
      loading: () => SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: size ?? 16,
            height: size ?? 16,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
