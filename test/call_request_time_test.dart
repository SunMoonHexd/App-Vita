import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/models/vita_models.dart';

void main() {
  group('Fechas de las solicitudes (zona horaria)', () {
    // Error real: dos dispositivos en zonas horarias distintas (celular en Bogotá, emulador en
    // UTC). Si la fecha se guarda sin zona, el otro dispositivo la lee corrida varias horas.
    test('se guardan en UTC, con la "Z" al final', () {
      final req = CallRequest(
        id: 'r1',
        elderlyId: 'e1',
        roomName: 'sala',
        joinCode: '123456',
        status: CallRequestStatus.connected,
        createdAt: DateTime(2026, 10, 12, 13, 33),
        startedAt: DateTime(2026, 10, 12, 13, 34),
      );
      final json = req.toJson();
      expect(json['createdAt'] as String, endsWith('Z'));
      expect(json['startedAt'] as String, endsWith('Z'));
    });

    test('al leerlas se recupera el mismo instante', () {
      final created = DateTime(2026, 10, 12, 13, 33);
      final started = DateTime(2026, 10, 12, 13, 34);
      final req = CallRequest(
        id: 'r1',
        elderlyId: 'e1',
        roomName: 'sala',
        joinCode: '123456',
        status: CallRequestStatus.connected,
        createdAt: created,
        startedAt: started,
      );
      final back = CallRequest.fromJson(req.toJson());
      expect(back.createdAt.isAtSameMomentAs(created), isTrue);
      expect(back.startedAt!.isAtSameMomentAs(started), isTrue);
    });

    test('una llamada recién conectada no parece de hace horas', () {
      final started = DateTime.now();
      final req = CallRequest(
        id: 'r1',
        elderlyId: 'e1',
        roomName: 'sala',
        joinCode: '123456',
        status: CallRequestStatus.connected,
        createdAt: started,
        startedAt: started,
      );
      final back = CallRequest.fromJson(req.toJson());
      expect(DateTime.now().difference(back.startedAt!).inMinutes, lessThan(1));
    });
  });
}
