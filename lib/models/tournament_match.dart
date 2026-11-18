class TournamentMatch {
  const TournamentMatch({
    required this.matchId,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.scheduledAt,
  });

  final int matchId;
  final int homeTeamId;
  final String homeTeamName;
  final int awayTeamId;
  final String awayTeamName;

  // Spring uses LocalDateTime: preserve the supplied wall time without UTC conversion.
  final DateTime scheduledAt;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) =>
      TournamentMatch(
        matchId: json['matchId'] as int,
        homeTeamId: json['homeTeamId'] as int,
        homeTeamName: json['homeTeamName'] as String,
        awayTeamId: json['awayTeamId'] as int,
        awayTeamName: json['awayTeamName'] as String,
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      );
}
