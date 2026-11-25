import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_rive_animation/screens/login_screen.dart';
import 'package:login_rive_animation/screens/password_reset_dialog.dart';
import 'package:login_rive_animation/screens/signup_screen.dart';

// Estas pruebas no inicializan Firebase ni crean cuentas ni envían correos.
void main() {
  // El runner Windows necesita rive_common_plugin.dll; comprobar Rive en Web.
  final skipRive =
      Platform.isWindows && !const bool.fromEnvironment('RUN_RIVE_TESTS');
  testWidgets(
    'login rejects empty fields with one global message',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(find.text('Escribe tu correo y contraseña.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.decoration?.errorText, isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
    skip: skipRive,
  );

  testWidgets(
    'login permits a weak existing password and clears loading on failure',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.enterText(
        find.byType(TextField).at(0),
        'usuario@example.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'x');
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Sin Firebase inicializado, el SDK falla localmente; no se contacta al servicio.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('no-app'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    skip: skipRive,
  );

  testWidgets(
    'sign up validates institutional email, every password rule and confirmation',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));
      final fields = find.byType(TextFormField);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(find.text('Escribe tu correo institucional.'), findsOneWidget);
      expect(find.text('Escribe una contraseña.'), findsOneWidget);
      expect(find.text('Confirma tu contraseña.'), findsOneWidget);

      for (final email in [
        'a@gmail.com',
        '.a@tecdesoftware.edu.mx',
        'a..b@tecdesoftware.edu.mx',
        'a@tecdesoftware.edu.mx.evil.com',
        'a@TECdesoftware.edu.mx',
      ]) {
        await tester.enterText(fields.at(0), email);
        await tester.tap(find.text('Crear cuenta'));
        await tester.pump();
        expect(
          find.text(
            'Usa un correo válido que termine en @tecdesoftware.edu.mx.',
          ),
          findsOneWidget,
        );
      }

      await tester.enterText(
        fields.at(0),
        'alumno.nombre+clase@tecdesoftware.edu.mx',
      );
      final invalidPasswords = {
        'Ab1!': 'Usa al menos 8 caracteres.',
        'abcdef1!': 'Incluye una mayúscula.',
        'ABCDEF1!': 'Incluye una minúscula.',
        'Abcdefg!': 'Incluye un número.',
        'Abcdefg1': 'Incluye un símbolo, por ejemplo !, @ o #.',
        'Abcdef1 ': 'Incluye un símbolo, por ejemplo !, @ o #.',
      };
      for (final entry in invalidPasswords.entries) {
        await tester.enterText(fields.at(1), entry.key);
        await tester.enterText(fields.at(2), entry.key);
        await tester.tap(find.text('Crear cuenta'));
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining('Usa un correo válido'), findsNothing);
      }

      await tester.enterText(fields.at(1), 'Abcdefg1!');
      await tester.enterText(fields.at(2), 'Diferente1!');
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('password reset validates email before calling Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PasswordResetDialog(initialEmail: 'correo-invalido'),
        ),
      ),
    );
    expect(find.text('correo-invalido'), findsOneWidget);
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pump();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
