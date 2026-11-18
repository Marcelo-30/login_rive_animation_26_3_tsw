import 'package:flutter_test/flutter_test.dart';
import 'package:login_rive_animation/services/football_api.dart';

void main() {
  test(
    'PostgreSQL-backed API creates, lists, searches and deletes all four resources',
    () async {
      final api = FootballApi();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      int? tournamentId;
      int? teamId;
      int? awayId;
      int? playerId;
      int? matchId;
      try {
        final tournament = await api.createTournament(
          name: 'Flutter integration $suffix',
          season: '2026',
        );
        tournamentId = tournament.tournamentId;
        expect(
          (await api.getTournaments(name: '$suffix')).single.tournamentId,
          tournamentId,
        );
        expect(await api.getTeams(tournamentId), isEmpty);
        expect(await api.getMatches(tournamentId), isEmpty);
        final home = await api.createTeam(
          tournamentId,
          name: 'Local $suffix',
          city: 'León',
        );
        teamId = home.teamId;
        final away = await api.createTeam(
          tournamentId,
          name: 'Visitante $suffix',
        );
        awayId = away.teamId;
        expect((await api.getTeams(tournamentId)).length, 2);
        expect(away.city, isNull);
        expect(await api.getPlayers(teamId), isEmpty);
        final player = await api.createPlayer(
          teamId,
          name: 'José $suffix',
          number: 8,
          position: 'Medio',
        );
        playerId = player.playerId;
        expect((await api.getPlayers(teamId)).single.name, 'José $suffix');
        final match = await api.createMatch(
          tournamentId,
          homeTeamId: teamId,
          awayTeamId: awayId,
          scheduledAt: DateTime(2026, 11, 20, 18, 30),
        );
        matchId = match.matchId;
        expect(match.homeTeamName, home.name);
        expect(
          (await api.getMatches(tournamentId)).single.scheduledAt.hour,
          18,
        );
        final reloaded = (await api.getTournaments()).singleWhere(
          (item) => item.tournamentId == tournamentId,
        );
        expect(reloaded.matches.single.matchId, matchId);
        expect(
          (await api.getTeams(tournamentId))
              .singleWhere((team) => team.teamId == teamId)
              .players
              .single
              .playerId,
          playerId,
        );
        await api.deleteMatch(matchId);
        matchId = null;
        await api.deletePlayer(playerId);
        playerId = null;
        await api.deleteTeam(teamId);
        teamId = null;
        await api.deleteTeam(awayId);
        awayId = null;
        await api.deleteTournament(tournamentId);
        tournamentId = null;
        expect(await api.getTournaments(name: '$suffix'), isEmpty);
      } finally {
        // Delete only records created by this test, in foreign-key order.
        try {
          if (matchId != null) await api.deleteMatch(matchId);
          if (playerId != null) await api.deletePlayer(playerId);
          if (teamId != null) await api.deleteTeam(teamId);
          if (awayId != null) await api.deleteTeam(awayId);
          if (tournamentId != null) await api.deleteTournament(tournamentId);
        } finally {
          api.close();
        }
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_API_TESTS'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
