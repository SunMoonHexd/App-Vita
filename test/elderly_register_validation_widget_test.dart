import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/features/elderly/elderly_register_view.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: VitaTheme.light, home: const ElderlyRegisterView()),
  );
  await tester.pumpAndSettle();
}

Future<void> _completePersonalStep(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Rosa Mayor');
  await tester.tap(find.text('Seleccionar fecha de nacimiento'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, '3001234567');
  await tester.ensureVisible(find.text('Continuar'));
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

Future<void> _reachConsentStep(WidgetTester tester) async {
  await _completePersonalStep(tester);
  if (find.text('Paso 3 de 3').evaluate().isNotEmpty) return;
  expect(find.text('Paso 2 de 3'), findsOneWidget);
  await tester.enterText(find.byType(TextField).first, '1234');
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Continuar'));
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  expect(find.text('Paso 3 de 3'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registro de adulto mayor requiere celular válido', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField).first, 'Rosa Mayor');
    await tester.tap(find.text('Seleccionar fecha de nacimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Revisa el número de celular. Escribe al menos 7 números.'), findsOneWidget);
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('PIN de tres dígitos no permite avanzar', (tester) async {
    await _open(tester);
    await _completePersonalStep(tester);
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Crea un PIN usando exactamente 4 números.'), findsOneWidget);
    expect(find.text('Paso 2 de 3'), findsOneWidget);
  });

  testWidgets('PIN de cuatro dígitos permite avanzar a confirmaciones', (tester) async {
    await _open(tester);
    await _completePersonalStep(tester);
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 3 de 3'), findsOneWidget);
    expect(find.text('¿Qué ofrece VITA?'), findsOneWidget);
  });

  testWidgets('último paso muestra las tres confirmaciones y enlaces legales', (tester) async {
    await _open(tester);
    await _reachConsentStep(tester);

    expect(find.text('Paso 3 de 3'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.text('Leer términos de uso'), findsOneWidget);
    expect(find.text('Leer política de privacidad'), findsOneWidget);
  });

  testWidgets('confirmaciones de familiar y autonomía se pueden marcar', (tester) async {
    await _open(tester);
    await _reachConsentStep(tester);
    await tester.ensureVisible(find.text('Confirmo que el familiar de contacto es mayor de 18 años.'));
    await tester.tap(find.text('Confirmo que el familiar de contacto es mayor de 18 años.'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Puedo usar la aplicación de forma autónoma.'));
    await tester.tap(find.text('Puedo usar la aplicación de forma autónoma.'));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tiles.map((tile) => tile.value), [true, true, false]);
  });
}
