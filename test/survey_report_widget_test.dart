import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/shared/survey_view.dart';

Future<VitaRepository> _repository() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return VitaRepository(storage: storage, jitsi: LiveKitCallService());
}

CallRequest _request() => CallRequest(
  id: 'call-1',
  elderlyId: 'elderly-1',
  volunteerId: 'volunteer-1',
  roomName: 'VITA_call-1',
  joinCode: '123456',
  status: CallRequestStatus.completed,
  createdAt: DateTime(2026, 10, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'encuesta permite valorar y abrir el reporte de la otra persona',
    (tester) async {
      final repository = await _repository();
      await tester.pumpWidget(
        VitaScope(
          repository: repository,
          child: MaterialApp(
            theme: VitaTheme.light,
            home: SurveyView(request: _request(), askAccompanied: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo fue la experiencia?'), findsOneWidget);
      expect(find.text('¿Te sentiste acompañado?'), findsOneWidget);
      await tester.tap(find.text('Bien').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reportar al voluntario'));
      await tester.tap(find.text('Reportar al voluntario'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar'), findsOneWidget);
      expect(find.text('Comportamiento inapropiado'), findsOneWidget);
      expect(find.text('Lenguaje ofensivo'), findsOneWidget);
      expect(find.text('Solicitud de dinero o datos'), findsOneWidget);

      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona un motivo.'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('encuesta de voluntario permite omitirla', (tester) async {
    final repository = await _repository();
    await tester.pumpWidget(
      VitaScope(
        repository: repository,
        child: MaterialApp(
          theme: VitaTheme.light,
          home: SurveyView(request: _request(), askAccompanied: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Te sentiste acompañado?'), findsNothing);
    expect(find.text('Reportar al adulto mayor'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo te fue?'), findsNothing);
  });
}
