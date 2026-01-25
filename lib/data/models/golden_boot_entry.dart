import 'package:equatable/equatable.dart';

/// A single row in the tournament "Golden Boot" list.
///
/// Note: `goals` is normalized to a non-null integer (null treated as 0).
class GoldenBootEntry extends Equatable {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final int? playerNumber;
  final int goals;

  const GoldenBootEntry({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.playerNumber,
    required this.goals,
  });

  @override
  List<Object?> get props => [playerId, playerName, teamId, teamName, playerNumber, goals];
}

