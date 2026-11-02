import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_login_view.dart';

class _LoginRepository extends VitaRepository {
  _LoginRepository() : super(storage: LocalStorageService(), jitsi: LiveKitCallService());

  String? loginEmail;
  String? loginPassword;
  String? resentEmail;
  String? resentPassword;
  String? recoveryEmail;

  @override
  Future<AuthResult> loginVolunteer({required String email, required String password}) async {
    loginEmail = email;
    loginPassword = password;
    return const AuthResult.error('Correo o contraseña incorrectos.');
  }

  @override
  Future<String> resendVerificationEmail({required String email, required String password}) async {
    resentEmail = email;
    resentPassword = password;
    return 'Revisa tu correo para verificar la cuenta.';
  }

  @override
  Future<String> startPasswordRecovery(String email) async {
    recoveryEmail = email;
    return '';
  }
}

Future<void> _pump(WidgetTester tester, _LoginRepository repository) async {
  await tester.pumpWidget(
    VitaScope(
      repository: repository,
      child: MaterialApp(theme: VitaTheme.light, home: const VolunteerLoginView()),
    ),
  );
  await tester.pumpAndSettle();
  // La comprobación real de conectividad tiene un timeout de tres segundos.
  // Dejarla terminar evita timers de Internet pendientes al desmontar el widget.
  await tester.pump(const Duration(seconds: 3));
}

Finder _loginButton() => find.ancestor(
  of: find.text('Ingresar'),
  matching: find.byType(ElevatedButton),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inicio de sesión muestra campos y bloquea datos incompletos', (tester) async {
    final repository = _LoginRepository();
    await _pump(tester, repository);

    expect(find.text('Bienvenido, voluntario'), findsOneWidget);
    expect(find.text('Tu correo'), findsOneWidget);
    expect(find.text('Tu contraseña'), findsWidgets);
    expect(tester.widget<ElevatedButton>(_loginButton()).onPressed, isNull);
    expect(repository.loginEmail, isNull);
  });

  testWidgets('credenciales válidas se envían y muestran error del servidor', (tester) async {
    final repository = _LoginRepository();
    await _pump(tester, repository);
    await tester.enterText(find.byType(TextField).first, '  ana@vita.test  ');
    await tester.enterText(find.byType(TextField).last, 'clave-segura');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(repository.loginEmail, 'ana@vita.test');
    expect(repository.loginPassword, 'clave-segura');
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('editar un campo limpia el error de acceso', (tester) async {
    final repository = _LoginRepository();
    await _pump(tester, repository);
    await tester.enterText(find.byType(TextField).first, 'ana@vita.test');
    await tester.enterText(find.byType(TextField).last, 'clave-segura');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'otra@vita.test');
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña incorrectos.'), findsNothing);
  });

  testWidgets('contraseña se puede mostrar y volver a ocultar', (tester) async {
    await _pump(tester, _LoginRepository());
    final passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isFalse);

    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isTrue);
  });

  testWidgets('reenviar verificación y abrir recuperación de contraseña', (tester) async {
    final repository = _LoginRepository();
    await _pump(tester, repository);
    await tester.enterText(find.byType(TextField).first, 'ana@vita.test');
    await tester.enterText(find.byType(TextField).last, 'clave-segura');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reenviar correo de verificación'));
    await tester.tap(find.text('Reenviar correo de verificación'));
    await tester.pumpAndSettle();

    expect(repository.resentEmail, 'ana@vita.test');
    expect(repository.resentPassword, 'clave-segura');
    expect(find.text('Revisa tu correo para verificar la cuenta.'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  ana@vita.test  ');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar enlace'));
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(repository.recoveryEmail, 'ana@vita.test');
    expect(find.textContaining('te llegará un mensaje con el enlace'), findsOneWidget);
  });
}
