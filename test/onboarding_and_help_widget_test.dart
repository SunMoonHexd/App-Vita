import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/auth/role_select_view.dart';
import 'package:vita_app/ui/features/auth/onboarding_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_gate_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_help_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_register_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_gate_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_help_view.dart';

Future<VitaRepository> _repositoryForTest() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return VitaRepository(storage: storage, jitsi: LiveKitCallService());
}

Future<void> _pumpWithRepository(
  WidgetTester tester,
  VitaRepository repository,
  Widget home,
) async {
  await tester.pumpWidget(
    VitaScope(
      repository: repository,
      child: MaterialApp(theme: VitaTheme.light, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding permite avanzar por las páginas y empezar', (
    tester,
  ) async {
    final repository = await _repositoryForTest();
    var finished = false;
    await _pumpWithRepository(
      tester,
      repository,
      OnboardingView(onDone: () => finished = true),
    );

    expect(find.text('Habla con alguien'), findsOneWidget);
    for (final title in [
      'Voluntarios verificados',
      'Tu seguridad es importante',
      'VITA ofrece compañía social',
    ]) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('el registro de adulto mayor valida datos antes de avanzar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: VitaTheme.light, home: const ElderlyRegisterView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 3'), findsOneWidget);
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Escribe tu nombre y apellidos para continuar.'),
      findsOneWidget,
    );
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('la pantalla inicial lleva al acceso de adulto mayor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: VitaTheme.light, home: const RoleSelectView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo vas a usar VITA?'), findsOneWidget);
    expect(find.text('Soy adulto mayor'), findsOneWidget);
    expect(find.text('Soy voluntario'), findsOneWidget);

    await tester.tap(find.text('Soy adulto mayor'));
    await tester.pumpAndSettle();
    expect(find.text('¡Qué bueno verte!'), findsOneWidget);
    expect(find.text('Ya tengo una cuenta'), findsOneWidget);
    expect(find.text('Quiero crear mi cuenta'), findsOneWidget);
  });

  testWidgets('el ingreso de adulto mayor avanza del celular al PIN', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: VitaTheme.light, home: const ElderlyGateView()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Número de celular'), findsOneWidget);
    for (final digit in '1234567'.split('')) {
      await tester.ensureVisible(find.text(digit));
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    expect(find.text('123 4567'), findsOneWidget);

    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('PIN de 4 números'), findsOneWidget);
    expect(find.text('Ahora marca tu PIN de 4 números.'), findsOneWidget);

    for (final digit in '2580'.split('')) {
      await tester.ensureVisible(find.text(digit));
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('la puerta de voluntariado abre el inicio de sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: VitaTheme.light, home: const VolunteerGateView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acompaña con tu tiempo'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('Quiero ser voluntario'), findsOneWidget);
    expect(find.text('Empezar registro'), findsOneWidget);
  });

  testWidgets('ayuda de adulto mayor muestra instrucciones y emergencias', (
    tester,
  ) async {
    final repository = await _repositoryForTest();
    await _pumpWithRepository(tester, repository, const ElderlyHelpView());

    expect(find.text('Pedir compañía es sencillo'), findsOneWidget);
    expect(find.text('PASO 1'), findsOneWidget);
    expect(find.text('PASO 2'), findsOneWidget);
    expect(find.text('PASO 3'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -380));
    await tester.pumpAndSettle();
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(
      richTexts.any(
        (richText) =>
            richText.text.toPlainText().contains('¿Prefieres usar tu voz?'),
      ),
      isTrue,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Llamar a emergencias · 123'), findsOneWidget);
    expect(find.text('Llamar a mi familiar'), findsNothing);
  });

  testWidgets('ayuda de voluntariado presenta pautas y canal de emergencia', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: VitaTheme.light, home: const VolunteerHelpView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayuda'), findsOneWidget);
    expect(find.text('¿Cómo recibir llamadas?'), findsOneWidget);
    expect(find.text('Cuida y cuídate'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Llamar a la línea 123'), findsOneWidget);
  });
}
