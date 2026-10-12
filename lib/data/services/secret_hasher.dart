import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash simple para PIN y contraseñas del prototipo. No sustituye un backend seguro.
String hashSecret(String value) {
  return sha256.convert(utf8.encode('vita-app|$value')).toString();
}

List<int> _pinWrapKey() => sha256.convert(utf8.encode('vita-app|pin-wrap')).bytes;

/// Ofuscación REVERSIBLE del PIN (no es cifrado: la clave está en el código de la app).
/// Solo se guarda en `private/{uid}`, que únicamente leen el propio adulto y coordinación,
/// para que coordinación pueda restablecer el PIN. Nunca debe quedar en un documento público.
String wrapPin(String pin) {
  final key = _pinWrapKey();
  final data = utf8.encode(pin);
  return base64Encode(List<int>.generate(data.length, (i) => data[i] ^ key[i % key.length]));
}

String? unwrapPin(String wrapped) {
  try {
    final key = _pinWrapKey();
    final data = base64Decode(wrapped);
    return utf8.decode(List<int>.generate(data.length, (i) => data[i] ^ key[i % key.length]));
  } catch (_) {
    return null;
  }
}
