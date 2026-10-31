import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vita_app/config/livekit_config.dart';

/// Habla con el Worker (servidor de pases y grabación). Cada petición va con el token de
/// Firebase de quien inició sesión, así el servidor sabe que es un usuario de VITA.
class LiveKitApi {
  static const _timeout = Duration(seconds: 20);

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!livekitConfigured) {
      throw Exception(
        'Falta configurar la dirección del servidor en lib/config/livekit_config.dart.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      throw Exception('Inicia sesión para usar la videollamada.');
    final idToken = await user.getIdToken();
    try {
      final response = await http
          .post(
            Uri.parse('$kTokenServerUrl$path'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $idToken',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(
          data['detail'] ?? data['error'] ?? 'Error ${response.statusCode}',
        );
      }
      return data;
    } on Exception catch (e) {
      final text = e.toString().replaceFirst('Exception: ', '');
      throw Exception(
        'No se pudo comunicar con el servidor de llamadas ($text).',
      );
    }
  }

  /// Pase para entrar a una sala. Devuelve (url de LiveKit, pase).
  static Future<({String url, String token})> fetchToken({
    required String roomName,
    required String requestId,
    required String displayName,
    String? supportRequestId,
  }) async {
    final data = await _post('/token', {
      'roomName': roomName,
      'requestId': requestId,
      'displayName': displayName,
      // Solo el psicólogo lo envía: el Worker comprueba que esa solicitud de apoyo esté aceptada por él.
      if (supportRequestId != null) 'supportRequestId': supportRequestId,
    });
    return (url: data['url'] as String, token: data['token'] as String);
  }

  /// Empieza a grabar la sala. Devuelve el id de la grabación.
  static Future<String> startRecording(String roomName) async {
    final data = await _post('/record/start', {'roomName': roomName});
    return data['egressId'] as String;
  }

  static Future<void> stopRecording(String egressId) async {
    await _post('/record/stop', {'egressId': egressId});
  }

  /// Avisa al Worker cuando una solicitud ya está asignada a un voluntario.
  static Future<void> notifyIncomingCall(String requestId) async {
    final result = await _post('/notifications/incoming-call', {
      'requestId': requestId,
    });
    if (result['delivered'] != true) {
      debugPrint(
        'Aviso al voluntario no enviado por el Worker: ${result['reason'] ?? 'motivo desconocido'}',
      );
    } else {
      debugPrint('El Worker aceptó el aviso para el voluntario.');
    }
  }
}
