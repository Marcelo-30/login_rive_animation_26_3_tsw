import 'player.dart';

class Team {
  const Team({
    required this.teamId,
    required this.name,
    required this.city,
    required this.tournamentId,
    required this.players,
  });

  final int teamId;
  final String name;
  final String? city;
  final int tournamentId;
  final List<Player> players;

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    teamId: json['teamId'] as int,
    name: json['name'] as String,
    city: json['city'] as String?,
    tournamentId: json['tournamentId'] as int,
    players: (json['players'] as List<dynamic>? ?? [])
        .map((item) => Player.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
