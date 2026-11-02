import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalStorageService', () {
    test(
      'devuelve vacío antes de iniciar y cuando no hay datos guardados',
      () async {
        final storage = LocalStorageService();
        expect(storage.load(), isEmpty);

        await storage.init();
        expect(storage.load(), isEmpty);
      },
    );

    test('guarda y recupera mapas JSON, incluidos valores anidados', () async {
      final storage = LocalStorageService();
      await storage.init();

      await storage.save({
        'role': 'elderly',
        'preferences': {'audioOnly': true, 'fontScale': 1.25},
      });

      expect(storage.load(), {
        'role': 'elderly',
        'preferences': {'audioOnly': true, 'fontScale': 1.25},
      });
    });

    test('limpia los datos guardados', () async {
      final storage = LocalStorageService();
      await storage.init();
      await storage.save({'session': 'cached'});

      await storage.clear();

      expect(storage.load(), isEmpty);
    });

    test('ignora JSON válido que no sea un mapa', () async {
      SharedPreferences.setMockInitialValues({'vita_store_v1': '[1, 2, 3]'});
      final storage = LocalStorageService();
      await storage.init();

      expect(storage.load(), isEmpty);
    });
  });
}
