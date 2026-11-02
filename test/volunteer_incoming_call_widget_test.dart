import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_incoming_call_view.dart';

CallRequest _request({
  CallRequestStatus status = CallRequestStatus.ringing,
  bool audioOnly = false,
}) => CallRequest(
  id: 'call-1',
  elderlyId: 'elderly-1',
  volunteerId: 'volunteer-1',
  roomName: 'VITA_call-1',
  joinCode: '123456',
  status: status,
  createdAt: DateTime(2026, 10, 20),
  audioOnly: audioOnly,
);

class _FakeRepository extends VitaRepository {
  _FakeRepository({required this.request, required this.user})
    : super(storage: LocalStorageService(), jitsi: LiveKitCallService());

  final CallRequest? request;
  final VitaUser? user;
  String? acceptedId;
  String? rejectedId;
  bool joined = false;

  @override
  VitaUser? get currentUser => user;

  @override
  List<CallRequest> get requests => request == null ? [] : [request!];

  @override
  Future<CallRequest> acceptRequest(String requestId) async {
    acceptedId = requestId;
    return request!;
  }

  @override
  Future<void> joinCurrentCall() async {
    joined = true;
  }

  @override
  Future<void> rejectRequest(String requestId) async {
    rejectedId = requestId;
  }
}

VitaUser _volunteer() => const VitaUser(
  id: 'volunteer-1',
  role: UserRole.volunteer,
  displayName: 'Ana Voluntaria',
  status: AccountStatus.active,
);

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository, {
  bool withLauncher = false,
}) async {
  await tester.pumpWidget(
    VitaScope(
      repository: repository,
      child: MaterialApp(
        theme: VitaTheme.light,
        home: withLauncher
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            VolunteerIncomingCallView(requestId: 'call-1'),
                      ),
                    ),
                    child: const Text('Abrir aviso'),
                  ),
                ),
              )
            : VolunteerIncomingCallView(requestId: 'call-1'),
      ),
    ),
  );
  // La pantalla de conexión contiene un indicador que gira indefinidamente;
  // pumpAndSettle esperaría para siempre a que dejara de animarse.
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solicitud vencida informa que ya no está disponible', (
    tester,
  ) async {
    final repository = _FakeRepository(request: null, user: _volunteer());
    await _pump(tester, repository);

    expect(find.text('Solicitud de videollamada'), findsOneWidget);
    expect(find.text('Esta solicitud ya no está disponible'), findsOneWidget);
    expect(
      find.text(
        'Puede que otra persona ya la haya atendido o que haya vencido.',
      ),
      findsOneWidget,
    );
    expect(find.text('Volver al inicio'), findsOneWidget);
  });

  testWidgets('solicitud conectada muestra el estado de espera', (
    tester,
  ) async {
    final repository = _FakeRepository(
      request: _request(status: CallRequestStatus.connected, audioOnly: true),
      user: _volunteer(),
    );
    await _pump(tester, repository);

    expect(find.text('Solicitud de llamada de voz'), findsOneWidget);
    expect(find.text('Conectando a la llamada…'), findsOneWidget);
    expect(
      find.text(
        'Estamos preparando la llamada de voz. Esto puede tardar unos segundos.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('aceptar llamada une al voluntario y abre la encuesta', (
    tester,
  ) async {
    final repository = _FakeRepository(
      request: _request(audioOnly: true),
      user: _volunteer(),
    );
    await _pump(tester, repository);

    expect(find.text('Alguien espera compañía'), findsOneWidget);
    expect(
      find.text(
        'La persona quiere conversar por voz. Acepta para iniciar la llamada.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Aceptar llamada'));
    await tester.pumpAndSettle();

    expect(repository.acceptedId, 'call-1');
    expect(repository.joined, isTrue);
    expect(find.text('¿Cómo te fue?'), findsOneWidget);
  });

  testWidgets('rechazar llamada retorna a la pantalla anterior', (
    tester,
  ) async {
    final repository = _FakeRepository(request: _request(), user: _volunteer());
    await _pump(tester, repository, withLauncher: true);

    await tester.tap(find.text('Abrir aviso'));
    await tester.pumpAndSettle();
    expect(find.text('Aceptar llamada'), findsOneWidget);
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    expect(repository.rejectedId, 'call-1');
    expect(find.text('Abrir aviso'), findsOneWidget);
  });
}
