import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_home_view.dart';

class _HomeRepository extends VitaRepository {
  _HomeRepository({required this.user, this.callRequests = const []})
    : super(storage: LocalStorageService(), jitsi: LiveKitCallService());

  final VitaUser? user;
  final List<CallRequest> callRequests;
  int presenceTouches = 0;

  @override
  VitaUser? get currentUser => user;

  @override
  List<CallRequest> get requests => callRequests;

  @override
  List<AvailabilitySlot> slotsFor(String volunteerId) => const [];

  @override
  Future<void> touchPresence() async {
    presenceTouches++;
  }
}

VitaUser _volunteer({bool verified = false, bool available = false}) =>
    VitaUser(
      id: 'volunteer-1',
      role: UserRole.volunteer,
      displayName: 'Ana María Pérez',
      status: AccountStatus.active,
      identityVerified: verified,
      available: available,
    );

CallRequest _completedCall() {
  final now = DateTime.now();
  return CallRequest(
    id: 'completed-1',
    elderlyId: 'elderly-1',
    volunteerId: 'volunteer-1',
    roomName: 'VITA_completed',
    joinCode: '123456',
    status: CallRequestStatus.completed,
    createdAt: now.subtract(const Duration(minutes: 10)),
    startedAt: now.subtract(const Duration(minutes: 10)),
    endedAt: now.subtract(const Duration(minutes: 5)),
  );
}

Future<void> _pump(WidgetTester tester, _HomeRepository repository) async {
  await tester.pumpWidget(
    VitaScope(
      repository: repository,
      child: MaterialApp(
        theme: VitaTheme.light,
        home: const VolunteerHomeView(),
      ),
    ),
  );
  // No settle: la vista del panel mantiene un Timer periódico de presencia.
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sin sesión muestra el estado de acceso cerrado', (tester) async {
    final repository = _HomeRepository(user: null);
    await _pump(tester, repository);

    expect(find.text('Voluntario'), findsOneWidget);
    expect(find.text('Sesión cerrada'), findsOneWidget);
  });

  testWidgets('voluntario pendiente ve verificación, resumen e identidad', (
    tester,
  ) async {
    final repository = _HomeRepository(
      user: _volunteer(),
      callRequests: [_completedCall()],
    );
    await _pump(tester, repository);

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Verificación pendiente'), findsOneWidget);
    expect(
      find.text('Verifica tu identidad para recibir llamadas'),
      findsOneWidget,
    );
    expect(find.text('1 llamada'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(repository.presenceTouches, 1);

    await tester.ensureVisible(find.text('Verificar identidad'));
    await tester.tap(find.text('Verificar identidad'));
    await tester.pumpAndSettle();
    expect(find.text('Verificar mi identidad'), findsOneWidget);
    expect(find.text('Cargar frente'), findsOneWidget);
    expect(find.text('Cargar reverso'), findsOneWidget);
  });

  testWidgets('voluntario verificado ve disponibilidad e historial', (
    tester,
  ) async {
    final repository = _HomeRepository(user: _volunteer(verified: true));
    await _pump(tester, repository);

    expect(find.text('Identidad verificada'), findsOneWidget);
    expect(find.text('Estás fuera de línea'), findsOneWidget);
    expect(
      find.text('Sin turnos: podrás recibir llamadas a cualquier hora.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mis horas').last);
    await tester.pumpAndSettle();
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.text('Total acompañando'), findsOneWidget);
  });
}
