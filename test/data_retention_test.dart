import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/audit_log.dart';
import 'package:vita_app/domain/data_retention.dart';
import 'package:vita_app/domain/models/vita_models.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 12);

  group('Retención de datos (F18.7)', () {
    test('un dato justo en el límite todavía no vence; un segundo después, sí', () {
      expect(isExpired(now.subtract(const Duration(days: 365)), now, 365), isFalse);
      expect(isExpired(now.subtract(const Duration(days: 365, seconds: 1)), now, 365), isTrue);
    });

    test('un dato reciente no vence', () {
      expect(isExpired(now.subtract(const Duration(days: 2)), now, 365), isFalse);
    });

    test('los días de retención se mantienen dentro del rango permitido', () {
      expect(clampRetention(5), kMinRetentionDays);
      expect(clampRetention(365), 365);
      expect(clampRetention(99999), kMaxRetentionDays);
    });
  });

  group('Anonimización de llamadas y reportes', () {
    test('una llamada anonimizada pierde las identidades y conserva fechas y estado', () {
      final call = CallRequest(
        id: 'r1',
        elderlyId: 'e1',
        roomName: 'sala-secreta',
        joinCode: '123456',
        status: CallRequestStatus.completed,
        createdAt: now,
        volunteerId: 'v1',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 7)),
      );
      final anon = call.anonymized();
      expect(anon.elderlyId, kAnonymized);
      expect(anon.volunteerId, kAnonymized);
      expect(anon.roomName, isNot('sala-secreta'));
      expect(anon.joinCode, isNot('123456'));
      expect(anon.status, CallRequestStatus.completed);
      expect(anon.endedAt, call.endedAt);
    });

    test('una llamada sin voluntario sigue sin voluntario', () {
      final call = CallRequest(
        id: 'r2',
        elderlyId: 'e1',
        roomName: 'sala',
        joinCode: '111111',
        status: CallRequestStatus.expired,
        createdAt: now,
      );
      expect(call.anonymized().volunteerId, isNull);
    });
  });

  group('Registro de auditoría (18.7.3)', () {
    test('una entrada sobrevive al JSON', () {
      final entry = AuditEntry(
        id: 'x',
        actorId: 'c1',
        actorName: 'Coordinación',
        action: 'account_suspended',
        targetId: 'u9',
        detail: 'prueba',
        createdAt: now,
      );
      final back = AuditEntry.fromJson(entry.toJson());
      expect(back.action, 'account_suspended');
      expect(back.targetId, 'u9');
      expect(back.createdAt.isAtSameMomentAs(now), isTrue);
    });

    test('las acciones conocidas tienen texto legible y las desconocidas se muestran tal cual', () {
      expect(auditLabel('account_suspended'), 'Suspendió una cuenta');
      expect(auditLabel('accion_rara'), 'accion_rara');
    });
  });
}
