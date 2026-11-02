import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/data/services/biometric_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BiometricAccess.clearProcessSession();
    BiometricAccess.enabledUidChanges.value = null;
  });

  group('BiometricAccess', () {
    test('recuerda credenciales solo en el proceso actual', () {
      BiometricAccess.markCredentialLogin('user-1');

      expect(BiometricAccess.wasCredentialAuthenticated('user-1'), isTrue);
      expect(BiometricAccess.wasCredentialAuthenticated('user-2'), isFalse);

      BiometricAccess.clearProcessSession();
      expect(BiometricAccess.wasCredentialAuthenticated('user-1'), isFalse);
    });

    test(
      'detecta si la biometría está habilitada para la cuenta indicada',
      () async {
        SharedPreferences.setMockInitialValues({
          'vita_biometric_enabled_uid': 'user-1',
        });

        expect(await BiometricAccess.isEnabledFor('user-1'), isTrue);
        expect(await BiometricAccess.isEnabledFor('user-2'), isFalse);
      },
    );

    test(
      'al cerrar sesión elimina solo las preferencias de esa cuenta',
      () async {
        SharedPreferences.setMockInitialValues({
          'vita_biometric_enabled_uid': 'user-1',
          'vita_biometric_choice_uid': 'user-1',
        });
        final preferences = await SharedPreferences.getInstance();
        BiometricAccess.enabledUidChanges.value = 'user-1';

        await BiometricAccess.clearFor('user-2');
        expect(preferences.getString('vita_biometric_enabled_uid'), 'user-1');
        expect(BiometricAccess.enabledUidChanges.value, 'user-1');

        await BiometricAccess.clearFor('user-1');
        expect(preferences.getString('vita_biometric_enabled_uid'), isNull);
        expect(preferences.getString('vita_biometric_choice_uid'), isNull);
        expect(BiometricAccess.enabledUidChanges.value, isNull);
      },
    );
  });
}
