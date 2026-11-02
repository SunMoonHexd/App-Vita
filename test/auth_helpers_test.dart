import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/auth_helpers.dart';

void main() {
  group('auth identifier helpers', () {
    test('normalizes a phone to digits for elderly sign-in', () {
      const phone = '+57 (300) 123-4567';

      expect(phoneDigits(phone), '573001234567');
      expect(elderlyAuthEmail(phone), '573001234567@telefono.vita.invalid');
      expect(elderlyAuthPassword('1234', phone), 'vita-1234-573001234567');
      expect(elderlyLockKey(phone), 'elderly:573001234567');
    });

    test('normalizes role and email in lock key', () {
      expect(
        emailLockKey('volunteer', '  Person@Example.com '),
        'volunteer:person@example.com',
      );
    });
  });

  group('authErrorMessage', () {
    const wrong = 'Datos incorrectos.';

    test('maps credential errors to the caller supplied message', () {
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'invalid-email',
      ]) {
        expect(authErrorMessage(code, wrong: wrong), wrong);
      }
    });

    test(
      'explains rate limits, network, disabled, and weak password errors',
      () {
        expect(
          authErrorMessage('too-many-requests', wrong: wrong),
          contains('Espera unos minutos'),
        );
        expect(
          authErrorMessage('network-request-failed', wrong: wrong),
          contains('Sin conexión a internet'),
        );
        expect(
          authErrorMessage('user-disabled', wrong: wrong),
          'Esta cuenta está deshabilitada.',
        );
        expect(
          authErrorMessage('weak-password', wrong: wrong),
          contains('mínimo 6 caracteres'),
        );
      },
    );

    test('includes an unrecognized Firebase error code', () {
      expect(
        authErrorMessage('some-new-code', wrong: wrong),
        'No se pudo completar la acción (some-new-code).',
      );
    });
  });

  group('account lock messages', () {
    final now = DateTime.utc(2026, 11, 1, 12);

    test('rounds remaining minutes up and gives elderly-specific help', () {
      expect(
        activeLockMessage(
          key: 'elderly:3001234567',
          lockedUntil: now.add(const Duration(seconds: 30)),
          now: now,
        ),
        contains('Espera 1 minuto(s). También puedes restablecer el PIN'),
      );
    });

    test('uses email recovery for a volunteer lock', () {
      expect(
        activeLockMessage(
          key: 'volunteer:a@example.com',
          lockedUntil: now.add(const Duration(minutes: 4)),
          now: now,
        ),
        contains('También puedes restablecer tu contraseña desde el correo.'),
      );
    });

    test('returns no message when the lock is expired or ends now', () {
      expect(
        activeLockMessage(
          key: 'volunteer:a@example.com',
          lockedUntil: now,
          now: now,
        ),
        isNull,
      );
      expect(
        activeLockMessage(
          key: 'volunteer:a@example.com',
          lockedUntil: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('failedAttemptDecision', () {
    final now = DateTime.utc(2026, 11, 1, 12);
    const wrong = 'PIN incorrecto.';

    test('reports remaining tries before the lock threshold', () {
      final result = failedAttemptDecision(
        key: 'elderly:1234567',
        previousAttempts: 2,
        previousLockedUntil: null,
        now: now,
        wrong: wrong,
      );

      expect(result.failedAttempts, 3);
      expect(result.lockedUntil, isNull);
      expect(result.message, '$wrong Te quedan 2 intento(s).');
    });

    test('locks an elderly account on the fifth failure', () {
      final result = failedAttemptDecision(
        key: 'elderly:1234567',
        previousAttempts: 4,
        previousLockedUntil: null,
        now: now,
        wrong: wrong,
      );

      expect(result.failedAttempts, 5);
      expect(result.lockedUntil, now.add(const Duration(minutes: 15)));
      expect(result.message, contains('tras 5 intentos fallidos'));
      expect(result.message, contains('Recupera el PIN con tu familiar'));
    });

    test('locks a volunteer with password recovery guidance', () {
      final result = failedAttemptDecision(
        key: 'volunteer:a@example.com',
        previousAttempts: 4,
        previousLockedUntil: null,
        now: now,
        wrong: wrong,
      );

      expect(result.message, contains('restablece tu contraseña'));
    });

    test('starts a fresh attempt cycle after an expired lock', () {
      final result = failedAttemptDecision(
        key: 'volunteer:a@example.com',
        previousAttempts: 4,
        previousLockedUntil: now.subtract(const Duration(seconds: 1)),
        now: now,
        wrong: wrong,
      );

      expect(result.failedAttempts, 1);
      expect(result.lockedUntil, isNull);
      expect(result.message, '$wrong Te quedan 4 intento(s).');
    });
  });
}
