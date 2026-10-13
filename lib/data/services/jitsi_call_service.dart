import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/config/call_settings.dart';
import 'package:vita_app/config/jaas_secrets.dart';
import 'package:vita_app/data/services/call_notice.dart';
import 'package:vita_app/data/services/jaas_token.dart';

/// Videollamadas con JaaS (Jitsi gestionado por 8x8).
class JitsiCallService {
  JitsiCallService({JitsiMeet? client}) : _client = client ?? JitsiMeet();

  final JitsiMeet _client;

  static const String _server = 'https://8x8.vc';

  /// Margen antes de colgar sola cuando la otra persona se va (por si se le cae el internet un instante).
  static const Duration _aloneGrace = Duration(seconds: 5);

  final Set<String> _remote = {};
  Timer? _aloneTimer;
  Timer? _breakTimer;

  String _breakMessage(int minutes) {
    final unit = minutes == 1 ? 'minuto' : 'minutos';
    return 'Llevan $minutes $unit conversando. Si quieren, pueden tomar una pausa. La llamada continúa.';
  }

  /// Sugiere una pausa cada cierto tiempo, sin cortar la llamada (RF36).
  void _startBreakTimer() {
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(kBreakSuggestionAfter, (timer) {
      final minutes = kBreakSuggestionAfter.inMinutes * timer.tick;
      final message = _breakMessage(minutes);
      CallNotice.show(message);
      // Se repite una vez más para que dé tiempo de leerlo.
      Future.delayed(const Duration(seconds: 4), () => CallNotice.show(message, vibrate: false));
    });
  }

  void _stopTimers() {
    _aloneTimer?.cancel();
    _breakTimer?.cancel();
  }

  bool get isNativeSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> join({
    required String roomName,
    required String displayName,
    required String userId,
    required VoidCallback onTerminated,
    VoidCallback? onInterrupted,
  }) async {
    if (!jaasConfigured) {
      throw Exception(
        'Falta configurar JaaS: completa lib/config/jaas_secrets.dart con el App ID, el Key ID y la clave privada.',
      );
    }

    _remote.clear();
    _stopTimers();

    final token = buildJaasToken(userId: userId, displayName: displayName, roomName: roomName);

    if (!isNativeSupported) {
      final uri = Uri.parse('$_server/$kJaasAppId/$roomName?jwt=$token');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('No se pudo abrir la videollamada en el navegador.');
      }
      onTerminated();
      return;
    }

    final options = JitsiMeetConferenceOptions(
      serverURL: _server,
      room: '$kJaasAppId/$roomName',
      token: token,
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'subject': 'Acompañamiento VITA',
        'prejoinPageEnabled': false,
        'prejoinConfig.enabled': false,
        'requireDisplayName': false,
        'disableProfile': true,
      },
      // Pantalla de llamada lo más simple posible: micrófono, cámara y colgar.
      featureFlags: {
        'unsaferoomwarning.enabled': false,
        'welcomepage.enabled': false,
        'prejoinpage.enabled': false,
        'recording.enabled': false,
        'live-streaming.enabled': false,
        'chat.enabled': false,
        'invite.enabled': false,
        'add-people.enabled': false,
        'calendar.enabled': false,
        'call-integration.enabled': false,
        'close-captions.enabled': false,
        'help.enabled': false,
        'kick-out.enabled': false,
        'lobby-mode.enabled': false,
        'meeting-name.enabled': false,
        'meeting-password.enabled': false,
        'overflow-menu.enabled': false,
        'raise-hand.enabled': false,
        'reactions.enabled': false,
        'security-options.enabled': false,
        'speakerstats.enabled': false,
        'tile-view.enabled': false,
        'video-share.enabled': false,
        'android.screensharing.enabled': false,
        'ios.screensharing.enabled': false,
        'conference-timer.enabled': true,
        'toolbox.alwaysVisible': true,
      },
      userInfo: JitsiMeetUserInfo(displayName: displayName),
    );

    await _client.join(
      options,
      JitsiMeetEventListener(
        conferenceJoined: (url) {
          _startBreakTimer();
        },
        participantJoined: (email, name, role, participantId) {
          if (participantId != null) _remote.add(participantId);
          _aloneTimer?.cancel();
        },
        // Si la otra persona se va y nadie vuelve en unos segundos, esta llamada también termina.
        participantLeft: (participantId) {
          if (participantId != null) _remote.remove(participantId);
          if (_remote.isEmpty) {
            _aloneTimer?.cancel();
            _aloneTimer = Timer(_aloneGrace, () {
              _client.hangUp();
            });
          }
        },
        conferenceTerminated: (url, error) {
          _stopTimers();
          // Con `error` la llamada se cortó por un problema (red, servidor); sin él, alguien colgó.
          if (error != null && onInterrupted != null) {
            onInterrupted();
          } else {
            onTerminated();
          }
        },
        readyToClose: () {
          _stopTimers();
          onTerminated();
        },
      ),
    );
  }
}
