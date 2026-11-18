import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../models/tournament_match.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class FootballApi {
  FootballApi({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       ) {
    final uri = Uri.parse(this.baseUrl);
    if (!uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiException(
        'API_BASE_URL debe ser una URL HTTP o HTTPS válida.',
      );
    }
  }

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  void close() => _client.close();

  Future<List<Tournament>> getTournaments({String? name}) => _getList(
    name == null || name.trim().isEmpty
        ? '/tournaments'
        : '/tournaments/search',
    Tournament.fromJson,
    query: name == null || name.trim().isEmpty ? null : {'name': name.trim()},
    emptyOn404: name != null && name.trim().isNotEmpty,
  );

  Future<List<Team>> getTeams(int tournamentId) => _getList(
    '/api/teams/tournament/$tournamentId',
    Team.fromJson,
    emptyOn404: true,
  );

  Future<List<Player>> getPlayers(int teamId) =>
      _getList('/api/players/team/$teamId', Player.fromJson, emptyOn404: true);

  Future<List<TournamentMatch>> getMatches(int tournamentId) => _getList(
    '/api/matches/tournament/$tournamentId',
    TournamentMatch.fromJson,
    emptyOn404: true,
  );

  Future<Tournament> createTournament({
    required String name,
    required String season,
  }) => _post('/tournaments', {
    'name': name,
    'season': season,
  }, Tournament.fromJson);

  Future<Team> createTeam(
    int tournamentId, {
    required String name,
    String? city,
  }) => _post('/api/teams/tournament/$tournamentId', {
    'name': name,
    'city': city,
  }, Team.fromJson);

  Future<Player> createPlayer(
    int teamId, {
    required String name,
    required int number,
    required String position,
  }) => _post('/api/players/team/$teamId', {
    'name': name,
    'number': number,
    'position': position,
  }, Player.fromJson);

  Future<TournamentMatch> createMatch(
    int tournamentId, {
    required int homeTeamId,
    required int awayTeamId,
    required DateTime scheduledAt,
  }) async {
    if (homeTeamId == awayTeamId) {
      throw const ApiException('Selecciona dos equipos diferentes.');
    }
    if (scheduledAt.isUtc) {
      throw const ApiException('La fecha del partido debe ser una hora local.');
    }
    return _post('/api/matches/tournament/$tournamentId', {
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'scheduledAt': scheduledAt.toIso8601String(),
    }, TournamentMatch.fromJson);
  }

  Future<void> deleteTournament(int id) => _delete('/tournaments/$id');
  Future<void> deleteTeam(int id) => _delete('/api/teams/$id');
  Future<void> deletePlayer(int id) => _delete('/api/players/$id');
  Future<void> deleteMatch(int id) => _delete('/api/matches/$id');

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, String>? query,
    bool emptyOn404 = false,
  }) async {
    final response = await _request('GET', path, query: query);
    // These filtered controllers return 404 with no body for an empty collection.
    if (emptyOn404 &&
        response.statusCode == 404 &&
        response.headers.containsKey('x-response-message') &&
        response.bodyBytes.isEmpty) {
      return [];
    }
    _checkStatus(response, 200);
    try {
      return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
          .map((item) => parse(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const ApiException('La API devolvió JSON o una fecha inválidos.');
    } on TypeError {
      throw const ApiException(
        'La respuesta de la API no coincide con el contrato esperado.',
      );
    }
  }

  Future<T> _post<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final response = await _request('POST', path, body: body);
    _checkStatus(response, 201);
    try {
      return parse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on FormatException {
      throw const ApiException('La API devolvió JSON o una fecha inválidos.');
    } on TypeError {
      throw const ApiException(
        'La respuesta de la API no coincide con el contrato esperado.',
      );
    }
  }

  Future<void> _delete(String path) async {
    _checkStatus(await _request('DELETE', path), 204);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    try {
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      return await (() async {
        final response = await _client.send(request);
        return http.Response.fromStream(response);
      })().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'La API tardó demasiado en responder. Intenta de nuevo.',
      );
    } on http.ClientException {
      throw ApiException(
        'No se pudo conectar con $baseUrl. Revisa Spring Boot, la red y CORS en Web.',
      );
    }
  }

  void _checkStatus(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    String? message = response.headers['x-response-message'];
    if (message == null && response.bodyBytes.isNotEmpty) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic>) {
          message =
              (body['detail'] ?? body['message'] ?? body['error']) as String?;
        }
      } on FormatException {
        // The match controller also returns plain-text validation errors.
        if (response.statusCode == 400 &&
            response.headers['content-type']?.startsWith('text/plain') ==
                true) {
          message = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      }
    }
    throw ApiException(
      'HTTP ${response.statusCode}: ${message ?? 'No se pudo completar la operación.'}',
      statusCode: response.statusCode,
    );
  }
}
