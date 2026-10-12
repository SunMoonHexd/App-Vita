import 'package:flutter/services.dart';

/// Muestra un aviso breve (mensaje y vibración) incluso encima de la pantalla de la videollamada.
class CallNotice {
  static const _channel = MethodChannel('vita/call_notice');

  static Future<void> show(String message, {bool vibrate = true}) async {
    try {
      await _channel.invokeMethod<void>('show', {'message': message, 'vibrate': vibrate});
    } catch (_) {
      // En plataformas sin soporte, simplemente no se muestra.
    }
  }
}
