import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/models/vita_models.dart';

void main() {
  group('Presencia del voluntario (lastSeenAt)', () {
    test('se guarda en UTC y se lee como el mismo instante', () {
      final seen = DateTime(2026, 10, 12, 14, 0);
      final user = VitaUser(
        id: 'v1',
        role: UserRole.volunteer,
        displayName: 'Vol',
        status: AccountStatus.active,
        available: true,
        lastSeenAt: seen,
      );
      final json = user.toJson();
      expect(json['lastSeenAt'] as String, endsWith('Z'));
      final back = VitaUser.fromJson(json);
      expect(back.lastSeenAt!.isAtSameMomentAs(seen), isTrue);
    });

    test('un usuario sin latido tiene lastSeenAt nulo', () {
      final user = VitaUser(
        id: 'v1',
        role: UserRole.volunteer,
        displayName: 'Vol',
        status: AccountStatus.active,
      );
      expect(user.lastSeenAt, isNull);
      expect(VitaUser.fromJson(user.toJson()).lastSeenAt, isNull);
    });

    test('copyWith conserva el latido anterior si no se indica uno nuevo', () {
      final seen = DateTime(2026, 10, 12, 14, 0);
      final user = VitaUser(
        id: 'v1',
        role: UserRole.volunteer,
        displayName: 'Vol',
        status: AccountStatus.active,
        lastSeenAt: seen,
      );
      expect(user.copyWith(available: false).lastSeenAt, seen);
    });
  });
}
