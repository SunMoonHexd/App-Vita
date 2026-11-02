import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/photo_widgets.dart';

Future<VitaRepository> _repository() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return VitaRepository(storage: storage, jitsi: LiveKitCallService());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'avatar de perfil sin foto muestra nombre y acceso para cambiarla',
    (tester) async {
      final repository = await _repository();
      final user = VitaUser(
        id: 'vol-1',
        role: UserRole.volunteer,
        displayName: 'Ana María',
        status: AccountStatus.active,
      );

      await tester.pumpWidget(
        VitaScope(
          repository: repository,
          child: MaterialApp(
            theme: VitaTheme.light,
            home: Scaffold(body: VitaPhotoAvatar(user: user)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agregar foto'), findsOneWidget);
      expect(find.bySemanticsLabel('Cambiar foto de perfil'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Cambiar foto de perfil'));
      await tester.pumpAndSettle();
      // Sin sesión activa, la acción termina de forma segura y no abre el selector.
      expect(find.text('Tomar una foto'), findsNothing);
    },
  );
}
