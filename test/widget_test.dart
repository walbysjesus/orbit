import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/main.dart';

void main() {
  testWidgets('Welcome screen loads correctly', (WidgetTester tester) async {
    // Construir la app
    await tester.pumpWidget(const MyApp());

    // Verificar que aparece el texto de bienvenida
    expect(find.text('Welcome to Orbit'), findsOneWidget);

    // Verificar que aparece el botón de registro
    expect(find.text('Registrarme'), findsOneWidget);

    // Verificar que aparece el botón de login
    expect(find.text('Ya tengo cuenta'), findsOneWidget);
  });
}
