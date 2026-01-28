import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_event.dart';

/// Repository for match events (goals, etc.) with real-time support
class SupabaseMatchEventRepository {
  final SupabaseClient _client;
  static const String _table = 'match_events';

  SupabaseMatchEventRepository(this._client);

  /// Get all events for a match
  Future<List<MatchEvent>> getEventsByMatch(String matchId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('match_id', matchId)
        .order('minute', nullsFirst: false)
        .order('created_at');

    return (response as List).map((json) => MatchEvent.fromJson(json)).toList();
  }

  /// Create a new match event (goal)
  Future<MatchEvent> createEvent(MatchEvent event) async {
    final response = await _client
        .from(_table)
        .insert(event.toJson()..remove('id')..remove('created_at'))
        .select()
        .single();

    return MatchEvent.fromJson(response);
  }

  /// Delete a match event
  Future<void> deleteEvent(String eventId) async {
    await _client.from(_table).delete().eq('id', eventId);
  }

  /// Delete all events for a match
  Future<void> deleteEventsByMatch(String matchId) async {
    await _client.from(_table).delete().eq('match_id', matchId);
  }

  /// Subscribe to real-time match events for a specific match
  /// Returns a StreamSubscription that should be cancelled when done
  Stream<List<MatchEvent>> subscribeToMatchEvents(String matchId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('minute', ascending: true)
        .map((data) => data.map((json) => MatchEvent.fromJson(json)).toList());
  }

  /// Get events grouped by team for a match
  Future<Map<String, List<MatchEvent>>> getEventsGroupedByTeam(String matchId) async {
    final events = await getEventsByMatch(matchId);
    final grouped = <String, List<MatchEvent>>{};
    
    for (final event in events) {
      final teamId = event.teamId ?? 'unknown';
      grouped.putIfAbsent(teamId, () => []).add(event);
    }
    
    return grouped;
  }
}
