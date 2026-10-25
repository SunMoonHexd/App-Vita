import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/call_health.dart';

void main() {
  group('Estado de la cámara y el micrófono (F6.10)', () {
    test('encendido y con dispositivo: funciona', () {
      expect(deviceHealth(wantedOn: true, failed: false, devicesFound: 1), DeviceHealth.ok);
    });

    test('apagado a propósito: no es un problema', () {
      final health = deviceHealth(wantedOn: false, failed: false, devicesFound: 1);
      expect(health, DeviceHealth.off);
      expect(needsAttention(health), isFalse);
    });

    test('si falló al abrir, se marca como fallido aunque haya dispositivos', () {
      final health = deviceHealth(wantedOn: false, failed: true, devicesFound: 2);
      expect(health, DeviceHealth.failed);
      expect(needsAttention(health), isTrue);
    });

    test('sin ningún dispositivo: no existe', () {
      final health = deviceHealth(wantedOn: true, failed: false, devicesFound: 0);
      expect(health, DeviceHealth.missing);
      expect(needsAttention(health), isTrue);
    });

    test('mientras no se sabe cuántos dispositivos hay, no se asume que faltan', () {
      expect(deviceHealth(wantedOn: true, failed: false), DeviceHealth.ok);
    });

    test('los mensajes nombran el dispositivo', () {
      expect(deviceMessage(DeviceHealth.failed, mic: true), contains('micrófono'));
      expect(deviceMessage(DeviceHealth.failed, mic: false), contains('cámara'));
      expect(deviceMessage(DeviceHealth.missing, mic: false), contains('ninguna cámara'));
    });
  });

  group('Indicador de conexión (F6.11)', () {
    test('reconectando manda sobre la calidad y avisa en rojo', () {
      final status = describeLink(LinkQuality.excellent, reconnecting: true);
      expect(status.label, contains('Reconectando'));
      expect(status.warn, isTrue);
      expect(status.bars, 0);
    });

    test('calidades malas se muestran en rojo', () {
      expect(describeLink(LinkQuality.lost, reconnecting: false).warn, isTrue);
      expect(describeLink(LinkQuality.poor, reconnecting: false).warn, isTrue);
      expect(describeLink(LinkQuality.poor, reconnecting: false).bars, 1);
    });

    test('calidades buenas suben las barras y no avisan', () {
      expect(describeLink(LinkQuality.good, reconnecting: false).bars, 2);
      expect(describeLink(LinkQuality.excellent, reconnecting: false).bars, 3);
      expect(describeLink(LinkQuality.good, reconnecting: false).warn, isFalse);
    });

    test('al principio, con calidad desconocida, no alarma', () {
      final status = describeLink(LinkQuality.unknown, reconnecting: false);
      expect(status.warn, isFalse);
      expect(status.label, contains('Conectando'));
    });

    test('solo «débil» y «sin conexión» cuentan como conexión mala', () {
      expect(isWeakLink(LinkQuality.poor), isTrue);
      expect(isWeakLink(LinkQuality.lost), isTrue);
      expect(isWeakLink(LinkQuality.good), isFalse);
      expect(isWeakLink(LinkQuality.unknown), isFalse);
    });
  });

  group('Reintentos al abrir un dispositivo (F6.12)', () {
    test('si funciona a la primera, no espera ni reintenta', () async {
      var calls = 0;
      final waits = <Duration>[];
      final ok = await tryWithRetries(() async => calls++, wait: (d) async => waits.add(d));
      expect(ok, isTrue);
      expect(calls, 1);
      expect(waits, isEmpty);
    });

    test('reintenta y termina en cuanto funciona', () async {
      var calls = 0;
      final ok = await tryWithRetries(() async {
        calls++;
        if (calls < 3) throw StateError('falla');
      }, wait: (d) async {});
      expect(ok, isTrue);
      expect(calls, 3);
    });

    test('se rinde cuando se acaban los reintentos', () async {
      var calls = 0;
      final ok = await tryWithRetries(() async {
        calls++;
        throw StateError('siempre falla');
      }, wait: (d) async {});
      expect(ok, isFalse);
      expect(calls, 1 + kDeviceRetryDelays.length);
    });

    test('espera lo indicado entre un intento y el siguiente', () async {
      final waits = <Duration>[];
      await tryWithRetries(() async => throw StateError('falla'), wait: (d) async => waits.add(d));
      expect(waits, kDeviceRetryDelays);
    });

    test('sin tiempos de espera, intenta una sola vez', () async {
      var calls = 0;
      final ok = await tryWithRetries(() async {
        calls++;
        throw StateError('falla');
      }, delays: const []);
      expect(ok, isFalse);
      expect(calls, 1);
    });
  });
}
