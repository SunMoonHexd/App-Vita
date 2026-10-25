import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/emergency_followup.dart';
import 'package:vita_app/domain/models/vita_models.dart';

EmergencyAlert alert({
  String id = 'a1',
  AlertStatus status = AlertStatus.open,
  DateTime? created,
  DateTime? familyNotifiedAt,
  FamilyOutcome familyOutcome = FamilyOutcome.pending,
  DateTime? alternateNotifiedAt,
  FamilyOutcome alternateOutcome = FamilyOutcome.pending,
}) {
  return EmergencyAlert(
    id: id,
    callId: 'c1',
    triggeredById: 'v1',
    elderlyId: 'e1',
    createdAt: created ?? DateTime.utc(2026, 10, 23, 15),
    status: status,
    familyNotifiedAt: familyNotifiedAt,
    familyOutcome: familyOutcome,
    alternateNotifiedAt: alternateNotifiedAt,
    alternateOutcome: alternateOutcome,
  );
}

EmergencyStep step(EmergencyAlert a, {bool family = true, bool alternate = true}) =>
    nextEmergencyStep(a, hasFamilyPhone: family, hasAlternatePhone: alternate);

void main() {
  final sent = DateTime.utc(2026, 10, 23, 15, 5);

  group('Qué sigue en una alerta (F8.7, F8.9 y F8.11)', () {
    test('al principio hay que avisar al familiar', () {
      expect(step(alert()), EmergencyStep.contactFamily);
    });

    test('ya avisado, falta anotar si respondió', () {
      expect(step(alert(familyNotifiedAt: sent)), EmergencyStep.awaitFamily);
    });

    test('si el familiar no contestó, se pasa al contacto alternativo', () {
      final a = alert(familyNotifiedAt: sent, familyOutcome: FamilyOutcome.noAnswer);
      expect(step(a), EmergencyStep.contactAlternate);
    });

    test('ya avisado el alternativo, falta anotar si respondió', () {
      final a = alert(
        familyNotifiedAt: sent,
        familyOutcome: FamilyOutcome.noAnswer,
        alternateNotifiedAt: sent,
      );
      expect(step(a), EmergencyStep.awaitAlternate);
    });

    test('si nadie contestó, el familiar es no localizable y se escala', () {
      final a = alert(
        familyNotifiedAt: sent,
        familyOutcome: FamilyOutcome.noAnswer,
        alternateNotifiedAt: sent,
        alternateOutcome: FamilyOutcome.noAnswer,
      );
      expect(step(a), EmergencyStep.escalate);
    });

    test('sin teléfono del familiar se salta directo al alternativo', () {
      expect(step(alert(), family: false), EmergencyStep.contactAlternate);
    });

    test('sin ningún teléfono se escala de inmediato', () {
      expect(step(alert(), family: false, alternate: false), EmergencyStep.escalate);
    });

    test('el familiar no contestó y no hay alternativo: se escala', () {
      final a = alert(familyNotifiedAt: sent, familyOutcome: FamilyOutcome.noAnswer);
      expect(step(a, alternate: false), EmergencyStep.escalate);
    });

    test('si alguien respondió, ya se puede cerrar', () {
      expect(step(alert(familyNotifiedAt: sent, familyOutcome: FamilyOutcome.reached)), EmergencyStep.readyToClose);
      final b = alert(
        familyOutcome: FamilyOutcome.noAnswer,
        alternateNotifiedAt: sent,
        alternateOutcome: FamilyOutcome.reached,
      );
      expect(step(b), EmergencyStep.readyToClose);
    });

    test('una alerta cerrada queda cerrada', () {
      expect(step(alert(status: AlertStatus.resolved)), EmergencyStep.closed);
    });
  });

  group('Mensaje al familiar y teléfonos', () {
    test('el mensaje dice quién, cuándo y qué hacer, y no pide datos de salud', () {
      final text = buildFamilyMessage(elderlyName: 'Rosa', when: DateTime(2026, 10, 23, 9, 5));
      expect(text, contains('Rosa'));
      expect(text, contains('23/10'));
      expect(text, contains('09:05'));
      expect(text, contains('123'));
    });

    test('un celular de 10 dígitos recibe el 57 para WhatsApp', () {
      expect(internationalPhone('300 123 4567'), '573001234567');
    });

    test('un número que ya trae el indicativo se deja como está', () {
      expect(internationalPhone('+57 300 123 4567'), '573001234567');
    });
  });

  group('Orden de las alertas', () {
    test('primero abiertas, luego en atención, al final cerradas; las más nuevas arriba', () {
      final list = [
        alert(id: 'cerrada', status: AlertStatus.resolved, created: DateTime.utc(2026, 10, 23, 18)),
        alert(id: 'abierta-vieja', created: DateTime.utc(2026, 10, 23, 10)),
        alert(id: 'atencion', status: AlertStatus.inProgress, created: DateTime.utc(2026, 10, 23, 12)),
        alert(id: 'abierta-nueva', created: DateTime.utc(2026, 10, 23, 14)),
      ];
      expect(sortAlerts(list).map((a) => a.id).toList(), ['abierta-nueva', 'abierta-vieja', 'atencion', 'cerrada']);
    });

    test('ordenar no cambia la lista original', () {
      final list = [alert(id: 'x', status: AlertStatus.resolved), alert(id: 'y')];
      sortAlerts(list);
      expect(list.first.id, 'x');
    });
  });

  group('La alerta como dato', () {
    test('una alerta guardada antes del seguimiento se lee como abierta y pendiente', () {
      final old = EmergencyAlert.fromJson({
        'id': 'a1',
        'callId': 'c1',
        'triggeredById': 'v1',
        'elderlyId': 'e1',
        'createdAt': '2026-10-23T15:00:00.000Z',
      });
      expect(old.status, AlertStatus.open);
      expect(old.familyOutcome, FamilyOutcome.pending);
      expect(old.alternateOutcome, FamilyOutcome.pending);
    });

    test('el seguimiento sobrevive al JSON', () {
      final a = alert(familyNotifiedAt: sent, familyOutcome: FamilyOutcome.noAnswer).copyWith(
        status: AlertStatus.resolved,
        resolutionNote: 'Se llamó al 123',
      );
      final back = EmergencyAlert.fromJson(a.toJson());
      expect(back.status, AlertStatus.resolved);
      expect(back.familyOutcome, FamilyOutcome.noAnswer);
      expect(back.familyNotifiedAt!.isAtSameMomentAs(sent), isTrue);
      expect(back.resolutionNote, 'Se llamó al 123');
    });

    test('anonimizar quita las identidades y la nota, pero deja fechas y estado', () {
      final a = alert(familyNotifiedAt: sent).copyWith(status: AlertStatus.resolved, resolvedById: 'c1', resolutionNote: 'datos');
      final anon = a.anonymized();
      expect(anon.isAnonymized, isTrue);
      expect(anon.triggeredById, kAnonymized);
      expect(anon.elderlyId, kAnonymized);
      expect(anon.resolvedById, kAnonymized);
      expect(anon.resolutionNote, isNull);
      expect(anon.status, AlertStatus.resolved);
      expect(anon.createdAt, a.createdAt);
    });
  });
}
