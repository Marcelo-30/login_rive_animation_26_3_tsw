class Player {
  const Player({
    required this.playerId,
    required this.name,
    required this.number,
    required this.position,
    required this.teamId,
  });

  final int playerId;
  final String name;
  final int number;
  final String position;
  final int teamId;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    playerId: json['playerId'] as int,
    name: json['name'] as String,
    number: json['number'] as int,
    position: json['position'] as String,
    teamId: json['teamId'] as int,
  );
}
