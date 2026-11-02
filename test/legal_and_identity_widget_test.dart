import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/shared/legal_text_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_identity_view.dart';

class _IdentityRepository extends VitaRepository {
  _IdentityRepository()
    : super(storage: LocalStorageService(), jitsi: LiveKitCallService());

  int saves = 0;
  int withdrawals = 0;

  @override
  Future<void> saveVolunteerIdentityDocuments({
    required String front,
    required String back,
  }) async {
    saves++;
  }

  @override
  Future<void> withdrawVolunteerIdentityConsent() async {
    withdrawals++;
  }
}

Future<_IdentityRepository> _repository() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return _IdentityRepository();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  _IdentityRepository? repository,
}) async {
  await tester.pumpWidget(
    VitaScope(
      repository: repository ?? await _repository(),
      child: MaterialApp(theme: VitaTheme.light, home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enlace de términos abre su contenido', (tester) async {
    await _pump(tester, const LegalLinks());

    await tester.tap(find.text('Leer términos de uso'));
    await tester.pumpAndSettle();

    expect(find.text('Términos de uso'), findsOneWidget);
    expect(find.text('Qué es VITA'), findsOneWidget);
    expect(find.textContaining('acompañamiento social'), findsWidgets);
  });

  testWidgets('enlace de privacidad abre el resumen de datos', (tester) async {
    await _pump(tester, const LegalLinks());

    await tester.tap(find.text('Leer política de privacidad'));
    await tester.pumpAndSettle();

    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.text('Qué información usamos'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Verificación de identidad de voluntarios'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Verificación de identidad de voluntarios'), findsOneWidget);
  });

  testWidgets('identidad exige autorización antes de guardar', (tester) async {
    final repository = await _repository();
    await _pump(
      tester,
      const VolunteerIdentityView(),
      repository: repository,
    );

    await tester.tap(find.text('Guardar y solicitar verificación'));
    await tester.pumpAndSettle();

    expect(
      find.text('Autoriza el uso de la cédula para verificar tu identidad.'),
      findsOneWidget,
    );
    expect(repository.saves, 0);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
  });

  testWidgets('identidad autorizada exige frente y reverso', (tester) async {
    final repository = await _repository();
    await _pump(
      tester,
      const VolunteerIdentityView(),
      repository: repository,
    );

    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Guardar y solicitar verificación'));
    await tester.pumpAndSettle();

    expect(find.text('Carga el frente y el reverso de la cédula.'), findsOneWidget);
    expect(repository.saves, 0);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
  });

  testWidgets('retirar autorización se puede cancelar sin borrar datos', (
    tester,
  ) async {
    final repository = await _repository();
    await _pump(
      tester,
      const VolunteerIdentityView(),
      repository: repository,
    );

    await tester.tap(find.text('Retirar autorización y borrar mi cédula'));
    await tester.pumpAndSettle();
    expect(find.text('Retirar autorización'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.withdrawals, 0);
    expect(find.text('Verificar mi identidad'), findsOneWidget);
  });
}
