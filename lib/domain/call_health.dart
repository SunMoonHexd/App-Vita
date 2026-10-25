/// Lógica pura para vigilar la videollamada (RF6 y RF24): estado de la cámara y del micrófono,
/// calidad de la conexión y reintentos. No depende de LiveKit, así se puede probar sola.

/// Estado de un dispositivo, para mostrárselo a la persona (F6.10).
enum DeviceHealth { ok, off, failed, missing }

/// Calidad de la conexión. Tiene los mismos niveles y nombres que informa LiveKit.
enum LinkQuality { unknown, lost, poor, good, excellent }

/// Lo que muestra el indicador de conexión de la llamada (F6.11).
class LinkStatus {
  const LinkStatus({required this.label, required this.bars, required this.warn});

  final String label;

  /// De 0 a 3 barras.
  final int bars;

  /// Si es true, el indicador se muestra en rojo.
  final bool warn;
}

/// Esperas antes de cada reintento al abrir la cámara o el micrófono (F6.12).
const List<Duration> kDeviceRetryDelays = [Duration(seconds: 2), Duration(seconds: 4)];

/// Estado de un dispositivo a partir de lo que se sabe de él. [devicesFound] es null mientras
/// todavía no se sabe cuántos dispositivos hay (no se asume que faltan).
DeviceHealth deviceHealth({required bool wantedOn, required bool failed, int? devicesFound}) {
  if (failed) return DeviceHealth.failed;
  if (devicesFound != null && devicesFound == 0) return DeviceHealth.missing;
  if (!wantedOn) return DeviceHealth.off;
  return DeviceHealth.ok;
}

/// Solo un dispositivo que falló o no existe necesita que la persona haga algo.
bool needsAttention(DeviceHealth health) => health == DeviceHealth.failed || health == DeviceHealth.missing;

/// Mensaje para la persona sobre el estado de la cámara o del micrófono (F6.10).
String deviceMessage(DeviceHealth health, {required bool mic}) {
  final name = mic ? 'el micrófono' : 'la cámara';
  return switch (health) {
    DeviceHealth.ok => mic ? 'Micrófono funcionando.' : 'Cámara funcionando.',
    DeviceHealth.off => mic ? 'Micrófono silenciado.' : 'Cámara apagada.',
    DeviceHealth.failed => 'No se pudo abrir $name.',
    DeviceHealth.missing => mic ? 'No se encontró ningún micrófono.' : 'No se encontró ninguna cámara.',
  };
}

/// Texto y barras del indicador de conexión (F6.11). Si se está reconectando, eso manda.
LinkStatus describeLink(LinkQuality quality, {required bool reconnecting}) {
  if (reconnecting) return const LinkStatus(label: 'Reconectando…', bars: 0, warn: true);
  return switch (quality) {
    LinkQuality.lost => const LinkStatus(label: 'Sin conexión', bars: 0, warn: true),
    LinkQuality.poor => const LinkStatus(label: 'Conexión débil', bars: 1, warn: true),
    LinkQuality.good => const LinkStatus(label: 'Conexión buena', bars: 2, warn: false),
    LinkQuality.excellent => const LinkStatus(label: 'Conexión excelente', bars: 3, warn: false),
    LinkQuality.unknown => const LinkStatus(label: 'Conectando…', bars: 0, warn: false),
  };
}

/// ¿La conexión está mal? Sirve para avisar una sola vez cuando empeora.
bool isWeakLink(LinkQuality quality) => quality == LinkQuality.poor || quality == LinkQuality.lost;

/// Ejecuta [action]; si falla, la repite esperando [delays] entre intentos (F6.12).
/// Devuelve true en cuanto funciona, o false cuando ya no quedan reintentos.
/// [wait] se puede reemplazar en las pruebas para no esperar de verdad.
Future<bool> tryWithRetries(
  Future<void> Function() action, {
  List<Duration> delays = kDeviceRetryDelays,
  Future<void> Function(Duration)? wait,
}) async {
  final pause = wait ?? (Duration d) => Future<void>.delayed(d);
  var attempt = 0;
  while (true) {
    try {
      await action();
      return true;
    } catch (_) {
      if (attempt >= delays.length) return false;
      await pause(delays[attempt]);
      attempt++;
    }
  }
}
