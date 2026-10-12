import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/data/services/secret_hasher.dart';

void main() {
  group('PIN ofuscado (wrapPin / unwrapPin)', () {
    test('ida y vuelta devuelve el mismo PIN', () {
      for (final pin in ['0000', '1234', '9876', '0007']) {
        expect(unwrapPin(wrapPin(pin)), pin);
      }
    });

    test('el valor guardado no contiene el PIN en claro', () {
      expect(wrapPin('1234'), isNot(contains('1234')));
    });

    test('un valor corrupto no revienta: devuelve null', () {
      expect(unwrapPin('esto no es base64 !!!'), isNull);
    });
  });

  group('hashSecret', () {
    test('es determinista y distingue entradas', () {
      expect(hashSecret('1234'), hashSecret('1234'));
      expect(hashSecret('1234'), isNot(hashSecret('1235')));
    });
  });
}
