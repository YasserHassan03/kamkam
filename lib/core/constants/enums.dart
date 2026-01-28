/// Visibility levels for organisations
enum Visibility {
  public,
  private,
  invite;

  String get displayName {
    switch (this) {
      case Visibility.public:
        return 'Public';
      case Visibility.private:
        return 'Private';
      case Visibility.invite:
        return 'Invite Only';
    }
  }

  static Visibility fromString(String value) {
    return Visibility.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => Visibility.public,
    );
  }
}

/// Tournament status
enum TournamentStatus {
  draft,
  active,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case TournamentStatus.draft:
        return 'Draft';
      case TournamentStatus.active:
        return 'Active';
      case TournamentStatus.completed:
        return 'Completed';
      case TournamentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static TournamentStatus fromString(String value) {
    return TournamentStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => TournamentStatus.draft,
    );
  }
}

/// Tournament type (league, knockout, etc.)
enum TournamentType {
  league,
  knockout,
  groupKnockout;

  String get displayName {
    switch (this) {
      case TournamentType.league:
        return 'League';
      case TournamentType.knockout:
        return 'Knockout';
      case TournamentType.groupKnockout:
        return 'Group + Knockout';
    }
  }

  String get jsonValue {
    switch (this) {
      case TournamentType.league:
        return 'league';
      case TournamentType.knockout:
        return 'knockout';
      case TournamentType.groupKnockout:
        return 'group_knockout';
    }
  }

  static TournamentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'knockout':
        return TournamentType.knockout;
      case 'group_knockout':
        return TournamentType.groupKnockout;
      default:
        return TournamentType.league;
    }
  }
}

/// Match status
enum MatchStatus {
  scheduled,
  inProgress,
  finished,
  postponed,
  cancelled;

  String get displayName {
    switch (this) {
      case MatchStatus.scheduled:
        return 'Scheduled';
      case MatchStatus.inProgress:
        return 'In Progress';
      case MatchStatus.finished:
        return 'Finished';
      case MatchStatus.postponed:
        return 'Postponed';
      case MatchStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get jsonValue {
    switch (this) {
      case MatchStatus.scheduled:
        return 'scheduled';
      case MatchStatus.inProgress:
        return 'in_progress';
      case MatchStatus.finished:
        return 'finished';
      case MatchStatus.postponed:
        return 'postponed';
      case MatchStatus.cancelled:
        return 'cancelled';
    }
  }

  static MatchStatus fromString(String value) {
    final cleanValue = value.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    switch (cleanValue) {
      case 'inprogress':
        return MatchStatus.inProgress;
      case 'finished':
        return MatchStatus.finished;
      case 'postponed':
        return MatchStatus.postponed;
      case 'cancelled':
        return MatchStatus.cancelled;
      default:
        return MatchStatus.scheduled;
    }
  }
}

/// Player positions
enum PlayerPosition {
  goalkeeper,
  defender,
  midfielder,
  forward;

  String get displayName {
    switch (this) {
      case PlayerPosition.goalkeeper:
        return 'Goalkeeper';
      case PlayerPosition.defender:
        return 'Defender';
      case PlayerPosition.midfielder:
        return 'Midfielder';
      case PlayerPosition.forward:
        return 'Forward';
    }
  }

  String get shortName {
    switch (this) {
      case PlayerPosition.goalkeeper:
        return 'GK';
      case PlayerPosition.defender:
        return 'DEF';
      case PlayerPosition.midfielder:
        return 'MID';
      case PlayerPosition.forward:
        return 'FWD';
    }
  }

  static PlayerPosition? fromString(String? value) {
    if (value == null) return null;
    return PlayerPosition.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PlayerPosition.midfielder,
    );
  }
}

/// Tiebreak criteria for league standings
enum TiebreakCriteria {
  points,
  goalDifference,
  goalsFor,
  headToHead;

  String get displayName {
    switch (this) {
      case TiebreakCriteria.points:
        return 'Points';
      case TiebreakCriteria.goalDifference:
        return 'Goal Difference';
      case TiebreakCriteria.goalsFor:
        return 'Goals Scored';
      case TiebreakCriteria.headToHead:
        return 'Head to Head';
    }
  }

  String get jsonValue {
    switch (this) {
      case TiebreakCriteria.points:
        return 'points';
      case TiebreakCriteria.goalDifference:
        return 'goal_difference';
      case TiebreakCriteria.goalsFor:
        return 'goals_for';
      case TiebreakCriteria.headToHead:
        return 'head_to_head';
    }
  }

  static TiebreakCriteria fromString(String value) {
    switch (value.toLowerCase()) {
      case 'goal_difference':
        return TiebreakCriteria.goalDifference;
      case 'goals_for':
        return TiebreakCriteria.goalsFor;
      case 'head_to_head':
        return TiebreakCriteria.headToHead;
      default:
        return TiebreakCriteria.points;
    }
  }
}

/// Match result type (for form display)
enum MatchResult {
  win,
  draw,
  loss;

  String get symbol {
    switch (this) {
      case MatchResult.win:
        return 'W';
      case MatchResult.draw:
        return 'D';
      case MatchResult.loss:
        return 'L';
    }
  }
}
