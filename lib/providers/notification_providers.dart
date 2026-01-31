import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the notification service singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Provider to check if this device is subscribed to a specific tournament or team
final isSubscribedProvider = FutureProvider.family<bool, ({String? tournamentId, String? teamId})>((ref, params) async {
  final client = Supabase.instance.client;
  final service = ref.watch(notificationServiceProvider);
  
  try {
    // We need the current device token to check if THIS device is subscribed
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return false;

      final query = client
          .from('user_subscriptions')
          .select()
          .eq('fcm_token', token);

      if (params.tournamentId != null) {
        query.eq('tournament_id', params.tournamentId as Object);
      } else {
        query.filter('tournament_id', 'is', null);
      }

      if (params.teamId != null) {
        query.eq('team_id', params.teamId as Object);
      } else {
        query.filter('team_id', 'is', null);
      }

      final response = await query.maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('NotificationProvider: Error checking subscription: $e');
      return false;
    }
});

/// Mutation provider to toggle subscription
final toggleSubscriptionProvider = FutureProvider.family<bool, ({String? tournamentId, String? teamId})>((ref, params) async {
  final service = ref.read(notificationServiceProvider);
  final result = await service.toggleSubscription(
    tournamentId: params.tournamentId,
    teamId: params.teamId,
  );
  
  // Refresh the subscription state
  ref.invalidate(isSubscribedProvider(params));
  return result;
});
