import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/call_lifecycle.dart';
import 'package:vita_app/domain/call_statistics.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/domain/support_request_queries.dart';

final DateTime now = DateTime.utc(2026, 11, 1, 18);

CallRequest call(
  String id, {
  CallRequestStatus status = CallRequestStatus.searching,
  DateTime? createdAt,
  DateTime? startedAt,
  String elderlyId = 'elderly',
  String? volunteerId = 'volunteer',
}) => CallRequest(
  id: id,
  elderlyId: elderlyId,
  volunteerId: volunteerId,
  roomName: 'room-$id',
  joinCode: '123456',
  status: status,
  createdAt: createdAt ?? now,
  startedAt: startedAt,
);

SupportRequest support(
  String id, {
  String callId = 'call-1',
  SupportStatus status = SupportStatus.open,
  String? psychologistId,
  DateTime? createdAt,
}) => SupportRequest(
  id: id,
  callId: callId,
  roomName: 'room-$callId',
  requestedById: 'volunteer',
  elderlyId: 'elderly',
  createdAt: createdAt ?? now,
  status: status,
  psychologistId: psychologistId,
);

void main() {
  group('Ciclo de vida de llamadas', () {
    test('solicitud buscando o sonando vence después de 10 minutos', () {
      for (final status in [
        CallRequestStatus.searching,
        CallRequestStatus.ringing,
      ]) {
        final old = call(
          'old-${status.name}',
          status: status,
          createdAt: now.subtract(const Duration(minutes: 10, seconds: 1)),
        );
        expect(
          normalizeCallRequest(old, now).status,
          CallRequestStatus.expired,
        );
      }
    });

    test('una llamada conectada se interrumpe después de cuatro horas', () {
      final old = call(
        'old-connected',
        status: CallRequestStatus.connected,
        startedAt: now.subtract(const Duration(hours: 4, seconds: 1)),
      );
      expect(
        normalizeCallRequest(old, now).status,
        CallRequestStatus.interrupted,
      );
    });

    test('no altera solicitudes dentro del plazo ni estados finales', () {
      final recent = call(
        'recent',
        status: CallRequestStatus.ringing,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );
      final completed = call('done', status: CallRequestStatus.completed);
      expect(
        normalizeCallRequest(recent, now).status,
        CallRequestStatus.ringing,
      );
      expect(normalizeCallRequest(completed, now), same(completed));
    });

    test('encuentra una llamada activa solo para uno de sus participantes', () {
      final requests = [
        call('done', status: CallRequestStatus.completed),
        call('active', status: CallRequestStatus.connected),
      ];
      expect(activeCallFor(requests, 'elderly')?.id, 'active');
      expect(activeCallFor(requests, 'volunteer')?.id, 'active');
      expect(activeCallFor(requests, 'other'), isNull);
      expect(activeCallFor(requests, null), isNull);
    });
  });

  group('Consultas de apoyo psicológico', () {
    test(
      'una solicitud abierta o aceptada sigue activa hasta las cuatro horas',
      () {
        final accepted = support(
          'accepted',
          status: SupportStatus.accepted,
          createdAt: now.subtract(const Duration(hours: 4)),
        );
        expect(activeSupportFor([accepted], 'call-1', now), same(accepted));
        expect(
          activeSupportFor(
            [
              support(
                'old',
                createdAt: now.subtract(const Duration(hours: 4, seconds: 1)),
              ),
            ],
            'call-1',
            now,
          ),
          isNull,
        );
      },
    );

    test('la bandeja muestra solo solicitudes abiertas recientes en orden', () {
      final older = support(
        'older',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      final newer = support(
        'newer',
        createdAt: now.subtract(const Duration(minutes: 1)),
      );
      final list = openSupportRequests([
        newer,
        older,
        support('accepted', status: SupportStatus.accepted),
        support(
          'expired',
          createdAt: now.subtract(const Duration(hours: 4, seconds: 1)),
        ),
      ], now);
      expect(list.map((request) => request.id), ['older', 'newer']);
    });

    test(
      'en curso solo muestra solicitudes aceptadas por el psicólogo actual',
      () {
        final mine = support(
          'mine',
          status: SupportStatus.accepted,
          psychologistId: 'psy-1',
        );
        final list = supportInProgressFor(
          [
            mine,
            support(
              'other',
              status: SupportStatus.accepted,
              psychologistId: 'psy-2',
            ),
            support('open', psychologistId: 'psy-1'),
            support(
              'old',
              status: SupportStatus.accepted,
              psychologistId: 'psy-1',
              createdAt: now.subtract(const Duration(hours: 4, seconds: 1)),
            ),
          ],
          'psy-1',
          now,
        );
        expect(list.map((request) => request.id), ['mine']);
        expect(supportInProgressFor([mine], null, now), isEmpty);
      },
    );
  });

  group('Estadísticas de llamadas', () {
    test('cuenta y suma solo llamadas completadas del voluntario indicado', () {
      final requests = [
        call(
          'done-1',
          status: CallRequestStatus.completed,
          volunteerId: 'v1',
          startedAt: now.subtract(const Duration(minutes: 5)),
          createdAt: now.subtract(const Duration(minutes: 5)),
        ).copyWith(endedAt: now.subtract(const Duration(minutes: 3))),
        call(
          'done-2',
          status: CallRequestStatus.completed,
          volunteerId: 'v2',
          startedAt: now.subtract(const Duration(minutes: 4)),
          createdAt: now.subtract(const Duration(minutes: 4)),
        ).copyWith(endedAt: now),
        call('ringing', status: CallRequestStatus.ringing, volunteerId: 'v1'),
      ];

      expect(completedCallCount(requests), 2);
      expect(
        volunteerCallTime(requests, 'v1', now),
        const Duration(minutes: 2),
      );
    });

    test('promedia llamadas con inicio e ignora las que no empezaron', () {
      final requests = [
        call(
          'a',
          status: CallRequestStatus.completed,
          startedAt: now.subtract(const Duration(seconds: 10)),
        ).copyWith(endedAt: now),
        call(
          'b',
          status: CallRequestStatus.completed,
          startedAt: now.subtract(const Duration(seconds: 21)),
        ).copyWith(endedAt: now),
        call('no-start', status: CallRequestStatus.completed),
        call('not-done', status: CallRequestStatus.connected, startedAt: now),
      ];
      expect(
        averageCompletedCallDuration(requests, now),
        const Duration(milliseconds: 15500),
      );
      expect(averageCompletedCallDuration([], now), Duration.zero);
    });

    test('una solicitud sin inicio tiene duración cero', () {
      expect(callDurationAt(call('not-started'), now), Duration.zero);
    });
  });
}
