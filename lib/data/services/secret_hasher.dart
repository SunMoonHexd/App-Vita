import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash simple para PIN y contraseñas del prototipo. No sustituye un backend seguro.
String hashSecret(String value) {
  return sha256.convert(utf8.encode('vita-app|$value')).toString();
}
