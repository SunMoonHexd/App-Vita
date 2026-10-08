import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

class JitsiCallService {
  JitsiCallService({JitsiMeet? client}) : _client = client ?? JitsiMeet();

  final JitsiMeet _client;

  bool get isNativeSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> join({
    required String roomName,
    required String displayName,
    required VoidCallback onTerminated,
  }) async {
    if (!isNativeSupported) {
      final uri = Uri.parse('https://meet.jit.si/$roomName');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('No se pudo abrir Jitsi en el navegador.');
      }
      onTerminated();
      return;
    }

    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.jit.si',
      room: roomName,
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'subject': 'Acompañamiento VITA',
        'prejoinPageEnabled': false,
        'disableProfile': true,
      },
      featureFlags: {
        'unsaferoomwarning.enabled': false,
        'welcomepage.enabled': false,
        'prejoinpage.enabled': false,
        'recording.enabled': false,
        'live-streaming.enabled': false,
        'toolbox.alwaysVisible': true,
      },
      userInfo: JitsiMeetUserInfo(displayName: displayName),
    );

    await _client.join(
      options,
      JitsiMeetEventListener(
        conferenceTerminated: (url, error) {
          onTerminated();
        },
        readyToClose: () {
          onTerminated();
        },
      ),
    );
  }
}
