import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login_rive_animation/models/team.dart';
import 'package:login_rive_animation/models/tournament.dart';
import 'package:login_rive_animation/services/football_api.dart';

const playerJson = {
  'playerId': 3,
  'name': 'José',
  'number': 8,
  'position': 'Medio',
  'teamId': 2,
};
const teamJson = {
  'teamId': 2,
  'name': 'León',
  'city': null,
  'tournamentId': 1,
  'players': [playerJson],
};
const matchJson = {
  'matchId': 4,
  'homeTeamId': 2,
  'homeTeamName': 'León',
  'awayTeamId': 5,
  'awayTeamName': 'Tigres',
  'scheduledAt': '2026-11-20T18:30:00',
};
const tournamentJson = {
  'tournamentId': 1,
  'name': 'Copa México',
  'season': '2026',
  'matches': [matchJson],
};

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late FootballApi api;

  tearDown(() => api.close());

  test(
    'reads real DTO field names, nested collections, UTF-8 and local dates',
    () async {
      api = FootballApi(
        client: MockClient(
          (request) async => switch (request.url.path) {
            '/tournaments' => jsonResponse([tournamentJson]),
            '/api/teams/tournament/1' => jsonResponse([teamJson]),
            '/api/players/team/2' => jsonResponse([playerJson]),
            '/api/matches/tournament/1' => jsonResponse([matchJson]),
            _ => http.Response('', 404),
          },
        ),
      );
      final tournament = (await api.getTournaments()).single;
      expect(tournament.tournamentId, 1);
      expect(tournament.name, 'Copa México');
      expect(tournament.matches.single.homeTeamName, 'León');
      expect((await api.getTeams(1)).single.players.single.name, 'José');
      expect((await api.getPlayers(2)).single.number, 8);
      final match = (await api.getMatches(1)).single;
      expect(match.scheduledAt.hour, 18);
      expect(match.scheduledAt.isUtc, isFalse);
      expect(Team.fromJson({...teamJson, 'players': null}).players, isEmpty);
      expect(
        Tournament.fromJson({...tournamentJson, 'matches': null}).matches,
        isEmpty,
      );
    },
  );

  test(
    'encodes search text as a query parameter and normalizes trailing slash',
    () async {
      api = FootballApi(
        baseUrl: 'http://localhost:8080/',
        client: MockClient((request) async {
          expect(request.url.path, '/tournaments/search');
          expect(request.url.queryParameters, {'name': 'Copa & México'});
          return jsonResponse([]);
        }),
      );
      expect(await api.getTournaments(name: ' Copa & México '), isEmpty);
    },
  );

  test(
    'interprets only controller empty-collection 404 responses as empty',
    () async {
      api = FootballApi(
        client: MockClient(
          (_) async => http.Response(
            '',
            404,
            headers: {'x-response-message': 'No records were found'},
          ),
        ),
      );
      expect(await api.getTeams(1), isEmpty);
      expect(await api.getPlayers(2), isEmpty);
      expect(await api.getMatches(1), isEmpty);
      expect(await api.getTournaments(name: 'missing'), isEmpty);
      await expectLater(
        api.getTournaments(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      api.close();
      api = FootballApi(
        client: MockClient((_) async => http.Response('', 404)),
      );
      await expectLater(api.getTeams(1), throwsA(isA<ApiException>()));
    },
  );

  test(
    'creates each resource using the exact POST payload and 201 response',
    () async {
      final sent = <String, Map<String, dynamic>>{};
      api = FootballApi(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['content-type'], contains('application/json'));
          expect(request.headers.containsKey('authorization'), isFalse);
          sent[request.url.path] =
              jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse(switch (request.url.path) {
            '/tournaments' => tournamentJson,
            '/api/teams/tournament/1' => teamJson,
            '/api/players/team/2' => playerJson,
            _ => matchJson,
          }, 201);
        }),
      );
      await api.createTournament(name: 'Copa México', season: '2026');
      await api.createTeam(1, name: 'León');
      await api.createPlayer(2, name: 'José', number: 8, position: 'Medio');
      await api.createMatch(
        1,
        homeTeamId: 2,
        awayTeamId: 5,
        scheduledAt: DateTime(2026, 11, 20, 18, 30),
      );
      expect(sent, {
        '/tournaments': {'name': 'Copa México', 'season': '2026'},
        '/api/teams/tournament/1': {'name': 'León', 'city': null},
        '/api/players/team/2': {
          'name': 'José',
          'number': 8,
          'position': 'Medio',
        },
        '/api/matches/tournament/1': {
          'homeTeamId': 2,
          'awayTeamId': 5,
          'scheduledAt': '2026-11-20T18:30:00.000',
        },
      });
      await expectLater(
        api.createMatch(
          1,
          homeTeamId: 2,
          awayTeamId: 2,
          scheduledAt: DateTime(2026),
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('accepts bodyless 204 DELETE responses for every resource', () async {
    final paths = <String>[];
    api = FootballApi(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        paths.add(request.url.path);
        return http.Response('', 204);
      }),
    );
    await api.deleteMatch(4);
    await api.deletePlayer(3);
    await api.deleteTeam(2);
    await api.deleteTournament(1);
    expect(paths, [
      '/api/matches/4',
      '/api/players/3',
      '/api/teams/2',
      '/tournaments/1',
    ]);
  });

  test(
    'surfaces server header and JSON errors without hiding HTTP failures',
    () async {
      api = FootballApi(
        client: MockClient(
          (_) async => http.Response(
            '',
            409,
            headers: {'x-response-message': 'Resource conflict'},
          ),
        ),
      );
      await expectLater(
        api.deleteTeam(2),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Resource conflict'),
          ),
        ),
      );
      api.close();
      api = FootballApi(
        client: MockClient(
          (_) async => jsonResponse({'message': 'Database unavailable'}, 500),
        ),
      );
      await expectLater(
        api.getTournaments(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Database unavailable'),
          ),
        ),
      );
    },
  );

  test('rejects invalid JSON and DTO shape', () async {
    api = FootballApi(
      client: MockClient((_) async => http.Response('not JSON', 200)),
    );
    await expectLater(api.getTournaments(), throwsA(isA<ApiException>()));
    api.close();
    api = FootballApi(
      client: MockClient(
        (_) async => jsonResponse([
          {'id': 1},
        ]),
      ),
    );
    await expectLater(api.getTournaments(), throwsA(isA<ApiException>()));
  });

  test('provides actionable network and timeout errors', () async {
    api = FootballApi(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      api.getTournaments(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('No se pudo conectar'),
        ),
      ),
    );
    api.close();
    api = FootballApi(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      api.getTournaments(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('demasiado'),
        ),
      ),
    );
  });
}
