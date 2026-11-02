import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_register_view.dart';

Future<VitaRepository> _repositoryForTest() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return VitaRepository(storage: storage, jitsi: LiveKitCallService());
}

Future<void> _pumpRegister(WidgetTester tester) async {
  final repository = await _repositoryForTest();
  await tester.pumpWidget(
    VitaScope(
      repository: repository,
      child: MaterialApp(
        theme: VitaTheme.light,
        home: VolunteerRegisterView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registro voluntario exige nombre antes de avanzar', (tester) async {
    await _pumpRegister(tester);

    expect(find.text('Paso 1 de 5'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe tu nombre y apellidos.'), findsOneWidget);
    expect(find.text('Paso 1 de 5'), findsOneWidget);
  });

  testWidgets('registro valida fecha de nacimiento y número de documento', (tester) async {
    await _pumpRegister(tester);

    await tester.enterText(find.byType(TextField).first, 'Ana Voluntaria');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Indica tu fecha de nacimiento.'), findsOneWidget);

    await tester.tap(find.text('Fecha de nacimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el número de tu documento.'), findsOneWidget);
    expect(find.text('Paso 1 de 5'), findsOneWidget);
  });
}
