import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/models/vita_models.dart';

void main() {
  group('Foto de perfil en VitaUser', () {
    const user = VitaUser(
      id: 'e1',
      role: UserRole.elderly,
      displayName: 'Ana',
      status: AccountStatus.active,
      photoBase64: 'Zm90bw==',
    );

    test('un usuario nuevo no tiene foto', () {
      const sinFoto = VitaUser(
        id: 'v1',
        role: UserRole.volunteer,
        displayName: 'Vol',
        status: AccountStatus.active,
      );
      expect(sinFoto.photoBase64, isNull);
    });

    test('la foto sobrevive a toJson y fromJson', () {
      expect(VitaUser.fromJson(user.toJson()).photoBase64, 'Zm90bw==');
    });

    test('un usuario guardado antes de existir la foto se sigue leyendo', () {
      final json = user.toJson()..remove('photoBase64');
      expect(VitaUser.fromJson(json).photoBase64, isNull);
    });

    test('copyWith conserva la foto si no se indica otra', () {
      expect(user.copyWith(displayName: 'Ana María').photoBase64, 'Zm90bw==');
    });

    test('copyWith cambia la foto por otra nueva', () {
      expect(user.copyWith(photoBase64: 'bnVldmE=').photoBase64, 'bnVldmE=');
    });

    test('copyWith con clearPhoto quita la foto', () {
      expect(user.copyWith(clearPhoto: true).photoBase64, isNull);
    });
  });
}
