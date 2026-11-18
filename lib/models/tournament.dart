import 'tournament_match.dart';

class Tournament {
  const Tournament({
    required this.tournamentId,
    required this.name,
    required this.season,
    required this.matches,
  });

  final int tournamentId;
  final String name;
  final String season;
  final List<TournamentMatch> matches;

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
    tournamentId: json['tournamentId'] as int,
    name: json['name'] as String,
    season: json['season'] as String,
    matches: (json['matches'] as List<dynamic>? ?? [])
        .map((item) => TournamentMatch.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
