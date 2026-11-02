import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/vita_theme_scope.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_profile_view.dart';

class _ProfileRepository extends VitaRepository {
  _ProfileRepository({this.user})
    : super(storage: LocalStorageService(), jitsi: LiveKitCallService());

  final VitaUser? user;

  @override
  VitaUser? get currentUser => user;

  @override
  List<CallRequest> get requests => const [];

  @override
  Duration volunteerHours(String volunteerId) => const Duration(minutes: 42);
}

const _pendingVolunteer = VitaUser(
  id: 'volunteer-1',
  role: UserRole.volunteer,
  displayName: 'Ana Voluntaria',
  status: AccountStatus.active,
  phone: '3001234567',
  email: 'ana@vita.test',
  documentId: '1234567890',
);

Future<void> _pump(WidgetTester tester, VitaUser? user) async {
  final controller = VitaThemeController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    VitaThemeScope(
      controller: controller,
      child: VitaScope(
        repository: _ProfileRepository(user: user),
        child: MaterialApp(
          theme: VitaTheme.light,
          home: const VolunteerProfileView(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('perfil sin sesión informa que la cuenta está cerrada', (tester) async {
    await _pump(tester, null);

    expect(find.text('Sesión cerrada'), findsOneWidget);
  });

  testWidgets('perfil pendiente oculta parte del documento', (tester) async {
    await _pump(tester, _pendingVolunteer);

    expect(find.text('Ana Voluntaria'), findsOneWidget);
    expect(find.text('Identidad pendiente'), findsOneWidget);
    expect(find.text('••••••7890'), findsOneWidget);
    expect(find.text('1234567890'), findsNothing);
  });

  testWidgets('perfil verificado informa que el documento fue eliminado', (tester) async {
    await _pump(
      tester,
      _pendingVolunteer.copyWith(identityVerified: true, clearDocumentId: true),
    );

    expect(find.text('Identidad verificada'), findsOneWidget);
    expect(
      find.text('Identidad verificada · número eliminado por privacidad'),
      findsOneWidget,
    );
    expect(find.text('42 min'), findsOneWidget);
    expect(find.text('Llamadas completadas'), findsOneWidget);
  });

  testWidgets('perfil abre política de privacidad', (tester) async {
    await _pump(tester, _pendingVolunteer);

    await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Política de privacidad'));
    await tester.pumpAndSettle();

    expect(find.text('Política de privacidad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Qué información usamos'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Qué información usamos'), findsOneWidget);
  });

  testWidgets('perfil abre términos y código de conducta', (tester) async {
    await _pump(tester, _pendingVolunteer);

    await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Términos y código de conducta'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Código de conducta del voluntario'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Términos y código de conducta'), findsOneWidget);
    expect(find.text('Código de conducta del voluntario'), findsOneWidget);
  });
}
