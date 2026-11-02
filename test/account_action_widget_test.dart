import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/elderly/elderly_actions.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_actions.dart';

class _ActionRepository extends VitaRepository {
  _ActionRepository({this.rejectPin = false, this.rejectPassword = false})
    : super(storage: LocalStorageService(), jitsi: LiveKitCallService());

  final bool rejectPin;
  final bool rejectPassword;
  String? checkedPin;
  String? checkedPassword;

  @override
  Future<void> verifyPin(String pin) async {
    checkedPin = pin;
    if (rejectPin) throw Exception('PIN incorrecto.');
  }

  @override
  Future<void> verifyPassword(String password) async {
    checkedPassword = password;
    if (rejectPassword) throw Exception('Contraseña incorrecta.');
  }
}

Future<_ActionRepository> _repository({
  bool rejectPin = false,
  bool rejectPassword = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return _ActionRepository(
    rejectPin: rejectPin,
    rejectPassword: rejectPassword,
  );
}

Future<void> _pump(
  WidgetTester tester,
  VitaRepository repository,
  Widget child,
) async {
  await tester.pumpWidget(
    VitaScope(
      repository: repository,
      child: MaterialApp(
        theme: VitaTheme.light,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('diálogo de PIN permite editarlo y cancelar sin verificar', (
    tester,
  ) async {
    final repository = await _repository();
    await _pump(
      tester,
      repository,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              confirmWithPin(context, title: 'Confirma con tu PIN'),
          child: const Text('Abrir PIN'),
        ),
      ),
    );

    await tester.tap(find.text('Abrir PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma con tu PIN'), findsOneWidget);
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Borrar'));
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma con tu PIN'), findsNothing);
  });

  testWidgets('confirmación de contraseña valida vacío, muestra y cancela', (
    tester,
  ) async {
    final repository = await _repository();
    await _pump(
      tester,
      repository,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              confirmWithPassword(context, title: 'Confirma tu contraseña'),
          child: const Text('Abrir contraseña'),
        ),
      ),
    );

    await tester.tap(find.text('Abrir contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma tu contraseña'), findsNothing);
  });

  testWidgets('PIN correcto confirma y cierra la hoja', (tester) async {
    final repository = await _repository();
    await _pump(
      tester,
      repository,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmWithPin(context, title: 'PIN'),
          child: const Text('Abrir PIN'),
        ),
      ),
    );

    await tester.tap(find.text('Abrir PIN'));
    await tester.pumpAndSettle();
    for (final digit in '1234'.split('')) {
      await tester.ensureVisible(find.text(digit));
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(repository.checkedPin, '1234');
    expect(find.text('PIN'), findsNothing);
  });

  testWidgets('PIN rechazado muestra el error y permite volver a intentar', (
    tester,
  ) async {
    final repository = await _repository(rejectPin: true);
    await _pump(
      tester,
      repository,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmWithPin(context, title: 'PIN'),
          child: const Text('Abrir PIN'),
        ),
      ),
    );

    await tester.tap(find.text('Abrir PIN'));
    await tester.pumpAndSettle();
    for (final digit in '1234'.split('')) {
      await tester.ensureVisible(find.text(digit));
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('PIN incorrecto.'), findsOneWidget);
    expect(repository.checkedPin, '1234');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('contraseña rechazada muestra error sin cerrar el diálogo', (
    tester,
  ) async {
    final repository = await _repository(rejectPassword: true);
    await _pump(
      tester,
      repository,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmWithPassword(context, title: 'Contraseña'),
          child: const Text('Abrir contraseña'),
        ),
      ),
    );

    await tester.tap(find.text('Abrir contraseña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'clave-de-prueba');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(repository.checkedPassword, 'clave-de-prueba');
    expect(find.text('Contraseña incorrecta.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('salir de la cuenta se puede cancelar', (tester) async {
    final repository = await _repository();
    await _pump(
      tester,
      repository,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmLogout(context),
          child: const Text('Salir'),
        ),
      ),
    );

    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quieres salir?'), findsOneWidget);
    await tester.tap(find.text('Quedarme'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quieres salir?'), findsNothing);
  });

  testWidgets('eliminación de cuenta se puede cancelar antes de confirmar', (
    tester,
  ) async {
    final repository = await _repository();
    await _pump(
      tester,
      repository,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmDeletion(context),
          child: const Text('Eliminar'),
        ),
      ),
    );

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar mis datos'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma con tu PIN'), findsNothing);
  });
}
