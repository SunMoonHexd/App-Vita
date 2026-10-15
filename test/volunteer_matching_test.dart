import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/domain/volunteer_matching.dart';

/// Martes 13 de octubre de 2026, 15:00 UTC = 10:00 en Colombia.
final DateTime kNow = DateTime.utc(2026, 10, 13, 15, 0);

VitaUser volunteer(
  String id, {
  bool available = true,
  AccountStatus status = AccountStatus.active,
  UserRole role = UserRole.volunteer,
  DateTime? now,
  Duration seenAgo = const Duration(seconds: 20),
  bool neverSeen = false,
  DateTime? lastCallAt,
}) {
  final at = now ?? kNow;
  return VitaUser(
    id: id,
    role: role,
    displayName: id,
    status: status,
    available: available,
    lastSeenAt: neverSeen ? null : at.subtract(seenAgo),
    lastCallAt: lastCallAt,
  );
}

CallRequest request(
  String id, {
  String? volunteerId,
  CallRequestStatus status = CallRequestStatus.searching,
}) {
  return CallRequest(
    id: id,
    elderlyId: 'adulto',
    roomName: 'sala-$id',
    joinCode: '123456',
    status: status,
    createdAt: kNow,
    volunteerId: volunteerId,
  );
}

AvailabilitySlot slot(String volunteerId, int weekday, int start, int end) {
  return AvailabilitySlot(
    id: '$volunteerId-$weekday-$start',
    volunteerId: volunteerId,
    weekday: weekday,
    startHour: start,
    endHour: end,
  );
}

List<String> ids(List<VitaUser> users) => users.map((u) => u.id).toList();

List<VitaUser> select(
  List<VitaUser> users, {
  List<CallRequest> requests = const [],
  List<AvailabilitySlot> slots = const [],
  DateTime? now,
  String? excludeId,
  String? ignoreRequestId,
}) {
  return selectVolunteers(
    users: users,
    requests: requests,
    slots: slots,
    now: now ?? kNow,
    excludeId: excludeId,
    ignoreRequestId: ignoreRequestId,
  );
}

void main() {
  group('Quién puede recibir una llamada', () {
    test('un voluntario activo, disponible y conectado entra', () {
      expect(ids(select([volunteer('v1')])), ['v1']);
    });

    test('no entra si no está marcado como disponible', () {
      expect(select([volunteer('v1', available: false)]), isEmpty);
    });

    test('no entra si la cuenta no está activa', () {
      for (final status in [AccountStatus.pending, AccountStatus.suspended, AccountStatus.blocked]) {
        expect(select([volunteer('v1', status: status)]), isEmpty, reason: status.name);
      }
    });

    test('un adulto mayor nunca entra, aunque esté disponible', () {
      expect(select([volunteer('a1', role: UserRole.elderly)]), isEmpty);
    });
  });

  group('Latido: voluntarios fantasma', () {
    test('sin ningún latido guardado no entra', () {
      expect(select([volunteer('v1', neverSeen: true)]), isEmpty);
    });

    test('con latido de hace 89 segundos entra; de hace 91, no', () {
      expect(select([volunteer('v1', seenAgo: const Duration(seconds: 89))]), isNotEmpty);
      expect(select([volunteer('v1', seenAgo: const Duration(seconds: 91))]), isEmpty);
    });

    test('un voluntario fantasma no tapa al que sí está conectado', () {
      final ghost = volunteer('fantasma', seenAgo: const Duration(minutes: 30), lastCallAt: DateTime.utc(2020));
      final real = volunteer('real', lastCallAt: DateTime.utc(2026, 10, 1));
      expect(ids(select([ghost, real])), ['real']);
    });
  });

  group('Turnos', () {
    test('sin franjas guardadas siempre está en turno', () {
      expect(select([volunteer('v1')], slots: []), isNotEmpty);
    });

    test('dentro de su franja entra; fuera, no', () {
      // Martes (2) de 8 a 12; ahora son las 10:00 en Colombia.
      expect(select([volunteer('v1')], slots: [slot('v1', 2, 8, 12)]), isNotEmpty);
      expect(select([volunteer('v1')], slots: [slot('v1', 2, 14, 18)]), isEmpty);
    });

    test('la franja de otro día no cuenta', () {
      expect(select([volunteer('v1')], slots: [slot('v1', 3, 0, 24)]), isEmpty);
    });

    test('la hora final de la franja no se incluye', () {
      // Ahora son las 10:00 y la franja termina a las 10:00.
      expect(select([volunteer('v1')], slots: [slot('v1', 2, 8, 10)]), isEmpty);
    });

    test('las franjas de otro voluntario no afectan a este', () {
      expect(select([volunteer('v1')], slots: [slot('v2', 2, 14, 18)]), isNotEmpty);
    });

    test('se mide con hora de Colombia aunque el celular esté en UTC (error real del emulador)', () {
      // 01:04 UTC del miércoles = 20:04 del martes en Colombia. Franja: martes de 8 a 24.
      final late = DateTime.utc(2026, 10, 14, 1, 4);
      final v = volunteer('v1', now: late);
      expect(select([v], slots: [slot('v1', 2, 8, 24)], now: late), isNotEmpty);
      // Y la franja del miércoles todavía no aplica a esa hora en Colombia.
      expect(select([v], slots: [slot('v1', 3, 8, 24)], now: late), isEmpty);
    });

    test('colombiaTime resta 5 horas y cambia el día cuando corresponde', () {
      final t = colombiaTime(DateTime.utc(2026, 10, 14, 1, 4));
      expect(t.weekday, DateTime.tuesday);
      expect(t.hour, 20);
    });
  });

  group('Ocupados', () {
    test('suena o está conectado: no entra', () {
      for (final status in [CallRequestStatus.ringing, CallRequestStatus.connected]) {
        expect(
          select([volunteer('v1')], requests: [request('r1', volunteerId: 'v1', status: status)]),
          isEmpty,
          reason: status.name,
        );
      }
    });

    test('llamadas terminadas, canceladas o vencidas no lo dejan ocupado', () {
      for (final status in [
        CallRequestStatus.completed,
        CallRequestStatus.interrupted,
        CallRequestStatus.cancelled,
        CallRequestStatus.expired,
      ]) {
        expect(
          select([volunteer('v1')], requests: [request('r1', volunteerId: 'v1', status: status)]),
          isNotEmpty,
          reason: status.name,
        );
      }
    });

    test('la solicitud que se está asignando no cuenta como "ocupado"', () {
      final r = request('r1', volunteerId: 'v1', status: CallRequestStatus.ringing);
      expect(select([volunteer('v1')], requests: [r]), isEmpty);
      expect(select([volunteer('v1')], requests: [r], ignoreRequestId: 'r1'), isNotEmpty);
    });

    test('se puede excluir a un voluntario concreto', () {
      expect(ids(select([volunteer('v1'), volunteer('v2')], excludeId: 'v1')), ['v2']);
    });
  });

  group('Orden', () {
    test('primero el que lleva más tiempo sin recibir una llamada', () {
      final users = [
        volunteer('reciente', lastCallAt: DateTime.utc(2026, 10, 13, 9)),
        volunteer('antiguo', lastCallAt: DateTime.utc(2026, 10, 1)),
        volunteer('medio', lastCallAt: DateTime.utc(2026, 10, 10)),
      ];
      expect(ids(select(users)), ['antiguo', 'medio', 'reciente']);
    });

    test('quien nunca ha recibido una llamada va primero', () {
      final users = [
        volunteer('con-historial', lastCallAt: DateTime.utc(2026, 10, 1)),
        volunteer('nuevo'),
      ];
      expect(ids(select(users)), ['nuevo', 'con-historial']);
    });
  });

  group('Elegir a quién le suena (chooseVolunteer)', () {
    VitaUser? choose(
      List<VitaUser> users, {
      List<CallRequest> requests = const [],
      String? previous,
      String? preferred,
    }) {
      return chooseVolunteer(
        users: users,
        requests: requests,
        slots: const [],
        now: kNow,
        requestId: 'r1',
        previousVolunteerId: previous,
        preferredId: preferred,
      );
    }

    test('sin nadie disponible devuelve null', () {
      expect(choose([volunteer('v1', available: false)]), isNull);
      expect(choose([]), isNull);
    });

    test('al reasignar, rota al siguiente voluntario', () {
      final users = [volunteer('v1', lastCallAt: DateTime.utc(2026, 10, 1)), volunteer('v2')];
      expect(choose(users, previous: 'v1')?.id, 'v2');
    });

    test('si el único disponible es el que ya sonaba, se le vuelve a avisar', () {
      final r = request('r1', volunteerId: 'v1', status: CallRequestStatus.ringing);
      expect(choose([volunteer('v1')], requests: [r], previous: 'v1')?.id, 'v1');
    });

    test('Llamar de nuevo: el voluntario preferido pasa al primer lugar', () {
      final users = [
        volunteer('v1', lastCallAt: DateTime.utc(2026, 10, 1)),
        volunteer('v2', lastCallAt: DateTime.utc(2026, 10, 5)),
      ];
      expect(choose(users)?.id, 'v1');
      expect(choose(users, preferred: 'v2')?.id, 'v2');
    });

    test('si el preferido ya no está disponible, se sigue el orden normal', () {
      final users = [volunteer('v1'), volunteer('v2', available: false)];
      expect(choose(users, preferred: 'v2')?.id, 'v1');
    });

    test('un voluntario ocupado en otra llamada no se elige aunque sea el preferido', () {
      final busy = request('otra', volunteerId: 'v2', status: CallRequestStatus.connected);
      final users = [volunteer('v1'), volunteer('v2')];
      expect(choose(users, requests: [busy], preferred: 'v2')?.id, 'v1');
    });
  });
}
