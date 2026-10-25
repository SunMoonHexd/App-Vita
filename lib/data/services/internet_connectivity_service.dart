import 'dart:io';

/// Comprueba que el dispositivo pueda resolver el servicio de Firebase.
/// No se limita a revisar si Wi-Fi o datos móviles están encendidos.
class InternetConnectivityService {
  static const _timeout = Duration(seconds: 3);

  static Future<bool> hasInternetConnection() async {
    try {
      final addresses = await InternetAddress.lookup('firebase.google.com').timeout(_timeout);
      return addresses.any((address) => address.rawAddress.isNotEmpty);
    } catch (_) {
      return false;
    }
  }
}
