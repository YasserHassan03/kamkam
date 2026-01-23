import 'package:flutter_test/flutter_test.dart';

import 'package:rondo_hub/data/models/standing.dart';
import 'package:rondo_hub/data/models/tournament.dart';

void main() {
  group('Standing Model Tests', () {
    test('Standing should calculate goal difference correctly', () {
      final standing = Standing(
        id: '1',
        tournamentId: 'tournament-1',
        teamId: 'team-1',
        played: 5,
        won: 3,
        drawn: 1,
        lost: 1,
        goalsFor: 10,
        goalsAgainst: 5,
        goalDifference: 5, // GF - GA = 10 - 5 = 5
        points: 10,
      );

      expect(standing.goalDifference, 5);
    });

    test('Standing with negative goal difference', () {
      final standing = Standing(
        id: '2',
        tournamentId: 'tournament-1',
        teamId: 'team-2',
        played: 5,
        won: 1,
        drawn: 0,
        lost: 4,
        goalsFor: 3,
        goalsAgainst: 12,
        goalDifference: -9, // GF - GA = 3 - 12 = -9
        points: 3,
      );

      expect(standing.goalDifference, -9);
    });

    test('Standing equality by id', () {
      final standing1 = Standing(
        id: '1',
        tournamentId: 'tournament-1',
        teamId: 'team-1',
        played: 5,
        won: 3,
        drawn: 1,
        lost: 1,
        goalsFor: 10,
        goalsAgainst: 5,
        points: 10,
      );

      final standing2 = Standing(
        id: '1',
        tournamentId: 'tournament-1',
        teamId: 'team-1',
        played: 5,
        won: 3,
        drawn: 1,
        lost: 1,
        goalsFor: 10,
        goalsAgainst: 5,
        points: 10,
      );

      expect(standing1, equals(standing2));
    });

    test('Standing copyWith works correctly', () {
      final original = Standing(
        id: '1',
        tournamentId: 'tournament-1',
        teamId: 'team-1',
        played: 5,
        won: 3,
        drawn: 1,
        lost: 1,
        goalsFor: 10,
        goalsAgainst: 5,
        points: 10,
      );

      final updated = original.copyWith(
        played: 6,
        won: 4,
        goalsFor: 13,
        points: 13,
      );

      expect(updated.id, original.id);
      expect(updated.played, 6);
      expect(updated.won, 4);
      expect(updated.goalsFor, 13);
      expect(updated.points, 13);
      // Unchanged fields
      expect(updated.drawn, original.drawn);
      expect(updated.lost, original.lost);
      expect(updated.goalsAgainst, original.goalsAgainst);
    });
  });

  group('TournamentRules Tests', () {
    test('Default tournament rules', () {
      const rules = TournamentRules();

      expect(rules.pointsForWin, 3);
      expect(rules.pointsForDraw, 1);
      expect(rules.pointsForLoss, 0);
      expect(rules.rounds, 1); // Default is single round-robin
      expect(rules.extraTimeAllowed, false);
    });

    test('Custom tournament rules', () {
      const rules = TournamentRules(
        matchDurationMinutes: 90,
        pointsForWin: 3,
        pointsForDraw: 1,
        pointsForLoss: 0,
        rounds: 1,
        extraTimeAllowed: true,
      );

      expect(rules.matchDurationMinutes, 90);
      expect(rules.rounds, 1);
      expect(rules.extraTimeAllowed, true);
    });

    test('TournamentRules JSON serialization', () {
      const rules = TournamentRules(
        matchDurationMinutes: 20,
        pointsForWin: 2,
        pointsForDraw: 1,
        pointsForLoss: 0,
        rounds: 3,
        extraTimeAllowed: true,
      );

      final json = rules.toJson();
      final restored = TournamentRules.fromJson(json);

      expect(restored.matchDurationMinutes, rules.matchDurationMinutes);
      expect(restored.pointsForWin, rules.pointsForWin);
      expect(restored.pointsForDraw, rules.pointsForDraw);
      expect(restored.pointsForLoss, rules.pointsForLoss);
      expect(restored.rounds, rules.rounds);
      expect(restored.extraTimeAllowed, rules.extraTimeAllowed);
    });
  });

  group('Standings Sorting Tests', () {
    test('Standings should sort by points, then goal difference, then goals for', () {
      final standings = [
        Standing(
          id: '1',
          tournamentId: 't1',
          teamId: 'team-c',
          played: 3,
          won: 1,
          drawn: 0,
          lost: 2,
          goalsFor: 4,
          goalsAgainst: 6,
          points: 3,
        ),
        Standing(
          id: '2',
          tournamentId: 't1',
          teamId: 'team-a',
          played: 3,
          won: 3,
          drawn: 0,
          lost: 0,
          goalsFor: 9,
          goalsAgainst: 2,
          points: 9,
        ),
        Standing(
          id: '3',
          tournamentId: 't1',
          teamId: 'team-b',
          played: 3,
          won: 2,
          drawn: 0,
          lost: 1,
          goalsFor: 5,
          goalsAgainst: 3,
          points: 6,
        ),
      ];

      // Sort: points DESC, goal difference DESC, goals for DESC
      standings.sort((a, b) {
        // First by points (descending)
        final pointsCompare = b.points.compareTo(a.points);
        if (pointsCompare != 0) return pointsCompare;

        // Then by goal difference (descending)
        final gdCompare = b.goalDifference.compareTo(a.goalDifference);
        if (gdCompare != 0) return gdCompare;

        // Then by goals for (descending)
        return b.goalsFor.compareTo(a.goalsFor);
      });

      expect(standings[0].teamId, 'team-a'); // 9 points, +7 GD
      expect(standings[1].teamId, 'team-b'); // 6 points, +2 GD
      expect(standings[2].teamId, 'team-c'); // 3 points, -2 GD
    });

    test('Standings tie-breaker by goal difference', () {
      final standings = [
        Standing(
          id: '1',
          tournamentId: 't1',
          teamId: 'team-a',
          played: 2,
          won: 1,
          drawn: 1,
          lost: 0,
          goalsFor: 3,
          goalsAgainst: 2,
          points: 4,
        ),
        Standing(
          id: '2',
          tournamentId: 't1',
          teamId: 'team-b',
          played: 2,
          won: 1,
          drawn: 1,
          lost: 0,
          goalsFor: 5,
          goalsAgainst: 2,
          points: 4,
        ),
      ];

      standings.sort((a, b) {
        final pointsCompare = b.points.compareTo(a.points);
        if (pointsCompare != 0) return pointsCompare;
        final gdCompare = b.goalDifference.compareTo(a.goalDifference);
        if (gdCompare != 0) return gdCompare;
        return b.goalsFor.compareTo(a.goalsFor);
      });

      // Both have 4 points, but team-b has +3 GD vs team-a's +1 GD
      expect(standings[0].teamId, 'team-b');
      expect(standings[1].teamId, 'team-a');
    });
  });
}
