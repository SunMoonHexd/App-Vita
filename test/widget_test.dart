import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/jitsi_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/main.dart';

void main() {
  testWidgets('Muestra la pantalla de selección de rol', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    final repo = VitaRepository(storage: storage, jitsi: JitsiCallService());
    await repo.bootstrap();

    await tester.pumpWidget(VitaApp(repository: repo));

    expect(find.text('Soy adulto mayor'), findsOneWidget);
    expect(find.text('Soy voluntario'), findsOneWidget);
  });
}