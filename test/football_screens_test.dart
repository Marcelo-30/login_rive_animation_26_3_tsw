import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login_rive_animation/screens/tournaments_screen.dart';
import 'package:login_rive_animation/services/football_api.dart';

import 'football_api_test.dart'
    show tournamentJson, teamJson, playerJson, jsonResponse;

void main() {
  testWidgets('shows loading and empty states', (tester) async {
    final response = Completer<http.Response>();
    final api = FootballApi(client: MockClient((_) => response.future));
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: TournamentsScreen(api: api)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(jsonResponse([]));
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay torneos registrados'), findsOneWidget);
  });

  testWidgets(
    'retries a failed request and navigates tournament to team players',
    (tester) async {
      var first = true;
      final api = FootballApi(
        client: MockClient((request) async {
          if (first) {
            first = false;
            return http.Response('', 500);
          }
          return switch (request.url.path) {
            '/tournaments' => jsonResponse([tournamentJson]),
            '/api/teams/tournament/1' => jsonResponse([teamJson]),
            '/api/players/team/2' => jsonResponse([playerJson]),
            _ => http.Response(
              '',
              404,
              headers: {'x-response-message': 'No matches were found'},
            ),
          };
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: TournamentsScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 500'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copa México'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partidos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no tiene partidos'), findsOneWidget);
      await tester.tap(find.text('Equipos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('León'));
      await tester.pumpAndSettle();
      expect(find.text('José'), findsOneWidget);
      expect(find.text('Medio'), findsOneWidget);
    },
  );

  testWidgets('validates tournament form, creates it and refreshes list', (
    tester,
  ) async {
    var created = false;
    final api = FootballApi(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'name': 'Copa México',
            'season': '2026',
          });
          created = true;
          return jsonResponse(tournamentJson, 201);
        }
        return jsonResponse(created ? [tournamentJson] : []);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: TournamentsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nuevo torneo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(created, isFalse);
    expect(find.text('Este campo es obligatorio.'), findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).at(0), 'Copa México');
    await tester.enterText(find.byType(TextFormField).at(1), '2026');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Copa México'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'requires confirmation for deletion and displays server errors in dialog',
    (tester) async {
      var deletions = 0;
      final api = FootballApi(
        client: MockClient((request) async {
          if (request.method == 'DELETE') {
            deletions++;
            return http.Response('', 500);
          }
          return jsonResponse([tournamentJson]);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: TournamentsScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eliminar torneo'));
      await tester.pumpAndSettle();
      expect(deletions, 0);
      expect(
        find.textContaining('equipos, jugadores y partidos'),
        findsOneWidget,
      );
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(deletions, 1);
      expect(find.textContaining('HTTP 500'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}
