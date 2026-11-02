import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/elderly/elderly_searching_view.dart';

CallRequest _request({
  bool audioOnly = false,
  CallRequestStatus status = CallRequestStatus.searching,
  String? volunteerId,
}) => CallRequest(
  id: 'search-1',
  elderlyId: 'elderly-1',
  volunteerId: volunteerId,
  roomName: 'VITA_search-1',
  joinCode: '123456',
  status: status,
  createdAt: DateTime(2026, 11, 2),
  audioOnly: audioOnly,
);

class _SearchRepository extends VitaRepository {
  _SearchRepository({
    this.failToStart = false,
    this.status = CallRequestStatus.searching,
    this.matchedUser,
  })
    : super(storage: LocalStorageService(), jitsi: LiveKitCallService());

  final bool failToStart;
  final CallRequestStatus status;
  final VitaUser? matchedUser;
  CallRequest? startedRequest;
  String? cancelledId;
  bool? requestedAudioOnly;

  @override
  VitaUser? get currentUser => const VitaUser(
    id: 'elderly-1',
    role: UserRole.elderly,
    displayName: 'Rosa Mayor',
    status: AccountStatus.active,
    familyPhone: '3001234567',
  );

  @override
  List<CallRequest> get requests => [if (startedRequest != null) startedRequest!];

  @override
  VitaUser? userById(String id) => matchedUser?.id == id ? matchedUser : null;

  @override
  Future<CallRequest> startCallRequest({bool audioOnly = false}) async {
    requestedAudioOnly = audioOnly;
    if (failToStart) throw Exception('No hay voluntarios disponibles.');
    startedRequest = _request(audioOnly: audioOnly, status: status,
      volunteerId: status == CallRequestStatus.ringing ? matchedUser?.id : null);
    return startedRequest!;
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    cancelledId = requestId;
  }
}

Future<void> _pumpSearch(
  WidgetTester tester,
  _SearchRepository repository, {
  bool audioOnly = false,
}) async {
  await tester.pumpWidget(
    VitaScope(
      repository: repository,
      child: MaterialApp(
        theme: VitaTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ElderlySearchingView(audioOnly: audioOnly),
                  ),
                ),
                child: const Text('Iniciar búsqueda'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Iniciar búsqueda'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('búsqueda de video muestra estado y código de sala', (tester) async {
    final repository = _SearchRepository();
    await _pumpSearch(tester, repository);

    expect(repository.requestedAudioOnly, isFalse);
    expect(find.text('Estamos buscando a alguien para acompañarte…'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('búsqueda de voz inicia en modo solo audio', (tester) async {
    final repository = _SearchRepository();
    await _pumpSearch(tester, repository, audioOnly: true);

    expect(repository.requestedAudioOnly, isTrue);
    expect(find.text('Buscamos a alguien para conversar por voz…'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('error al iniciar permite regresar a la pantalla anterior', (tester) async {
    final repository = _SearchRepository(failToStart: true);
    await _pumpSearch(tester, repository);

    expect(find.text('No hay voluntarios disponibles.'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pump();

    expect(find.text('Iniciar búsqueda'), findsOneWidget);
  });

  testWidgets('ayuda de llamada de voz explica cómo usar el micrófono', (tester) async {
    await _pumpSearch(tester, _SearchRepository(), audioOnly: true);

    await tester.tap(find.text('Ayuda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('La llamada será solo de voz'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pump();
  });

  testWidgets('cancelar búsqueda registra la solicitud y vuelve', (tester) async {
    final repository = _SearchRepository();
    await _pumpSearch(tester, repository);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();

    expect(repository.cancelledId, 'search-1');
    expect(find.text('Iniciar búsqueda'), findsOneWidget);
  });

  testWidgets('voluntario verificado muestra su presentación al ser encontrado', (tester) async {
    final volunteer = const VitaUser(
      id: 'volunteer-1',
      role: UserRole.volunteer,
      displayName: 'Ana Voluntaria',
      status: AccountStatus.active,
      identityVerified: true,
      volunteerPresentationConsent: true,
      volunteerPresentationReviewed: true,
      volunteerBio: 'Me gusta conversar sobre música.',
      volunteerInterests: 'Música',
      volunteerExperience: 'Acompaño a personas mayores.',
    );
    await _pumpSearch(
      tester,
      _SearchRepository(
        status: CallRequestStatus.ringing,
        matchedUser: volunteer,
      ),
    );

    expect(find.text('¡Encontramos un voluntario! Esperando que conteste…'), findsOneWidget);
    expect(find.text('Ana Voluntaria'), findsOneWidget);
    expect(find.text('Identidad verificada por coordinación'), findsOneWidget);
    expect(find.text('Me gusta conversar sobre música.'), findsOneWidget);
    expect(find.text('Intereses: Música'), findsOneWidget);
    expect(find.text('Voluntariado: Acompaño a personas mayores.'), findsOneWidget);
  });

  testWidgets('presentación no se muestra si coordinación no verificó identidad', (tester) async {
    final volunteer = const VitaUser(
      id: 'volunteer-1',
      role: UserRole.volunteer,
      displayName: 'Ana Voluntaria',
      status: AccountStatus.active,
      identityVerified: false,
      volunteerPresentationConsent: true,
      volunteerPresentationReviewed: true,
      volunteerBio: 'Presentación privada.',
    );
    await _pumpSearch(
      tester,
      _SearchRepository(
        status: CallRequestStatus.ringing,
        matchedUser: volunteer,
      ),
    );

    expect(find.text('Presentación privada.'), findsNothing);
    expect(find.text('Identidad verificada por coordinación'), findsNothing);
  });

  testWidgets('no presenta como voluntario a un usuario de otro perfil', (tester) async {
    final otherUser = const VitaUser(
      id: 'volunteer-1',
      role: UserRole.elderly,
      displayName: 'Otra cuenta',
      status: AccountStatus.active,
      identityVerified: true,
      volunteerPresentationConsent: true,
      volunteerPresentationReviewed: true,
      volunteerBio: 'Este texto no debe mostrarse.',
    );
    await _pumpSearch(
      tester,
      _SearchRepository(
        status: CallRequestStatus.ringing,
        matchedUser: otherUser,
      ),
    );

    expect(find.text('Otra cuenta'), findsNothing);
    expect(find.text('Este texto no debe mostrarse.'), findsNothing);
  });

  testWidgets('ayuda de videollamada explica cámara y micrófono', (tester) async {
    await _pumpSearch(tester, _SearchRepository());

    await tester.tap(find.text('Ayuda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('permite la cámara'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pump();
  });

  testWidgets('emergencia se puede cancelar sin salir de la búsqueda', (tester) async {
    final repository = _SearchRepository();
    await _pumpSearch(tester, repository);

    await tester.tap(find.text('Emergencia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('¿Llamar a tu familiar?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pump();

    expect(find.text('Cancelar'), findsOneWidget);
    expect(repository.cancelledId, isNull);
  });
}
