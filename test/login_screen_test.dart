import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:orbit/screens/auth/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renderiza campos y botón de login',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('muestra error si los campos están vacíos',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      expect(find.text('Campo requerido'), findsNWidgets(2));
    });
  });
}
