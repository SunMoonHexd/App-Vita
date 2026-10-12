import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:vita_app/config/jaas_secrets.dart';

/// Genera el "pase" (JWT) que JaaS pide para entrar a una sala.
///
/// Todos entran como moderadores, así nadie queda esperando a un anfitrión
/// ni tiene que iniciar sesión.
///
/// OJO: firmar el pase dentro de la app deja la clave privada dentro del APK.
/// Sirve para pruebas con un grupo cerrado. Para publicar, la firma debe moverse
/// a un servidor (por ejemplo, una función de Firebase).
String buildJaasToken({
  required String userId,
  required String displayName,
  required String roomName,
}) {
  final now = DateTime.now().toUtc();
  final jwt = JWT(
    {
      'room': roomName,
      'nbf': now.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch ~/ 1000,
      'context': {
        'user': {
          'id': userId,
          'name': displayName,
          'moderator': true,
        },
        'features': {
          'livestreaming': false,
          'recording': false,
          'outbound-call': false,
          'transcription': false,
        },
      },
    },
    issuer: 'chat',
    subject: kJaasAppId,
    audience: Audience.one('jitsi'),
    header: {'kid': kJaasKeyId},
  );
  return jwt.sign(
    RSAPrivateKey(kJaasPrivateKey.trim()),
    algorithm: JWTAlgorithm.RS256,
    expiresIn: const Duration(hours: 3),
  );
}
