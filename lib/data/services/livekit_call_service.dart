import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:vita_app/config/app_navigator.dart';
import 'package:vita_app/config/call_settings.dart';
import 'package:vita_app/data/services/call_notice.dart';
import 'package:vita_app/data/services/livekit_api.dart';
import 'package:vita_app/ui/features/call/livekit_call_screen.dart';

/// Estado de la grabación de la llamada, que siempre necesita el permiso de las dos personas.
enum RecordingPhase { idle, waitingAnswer, askingMe, starting, recording }

/// Videollamadas con LiveKit. Mantiene la misma interfaz que tenía el servicio de Jitsi
/// (`join` y `hangUp`), así el resto de la app casi no cambia.
class LiveKitCallService extends ChangeNotifier {
  /// Margen antes de colgar sola cuando la otra persona se va (por si se le cae el internet un instante).
  static const Duration _aloneGrace = Duration(seconds: 5);

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Route<void>? _route;
  Completer<void>? _closed;
  String _roomName = '';
  bool _interrupted = false;
  bool _reconnecting = false;
  bool _micOn = true;
  bool _camOn = true;
  DateTime? _joinedAt;
  Timer? _aloneTimer;
  Timer? _breakTimer;

  // Grabación
  RecordingPhase _phase = RecordingPhase.idle;
  String? _egressId;
  String _requesterName = '';
  String _displayName = '';

  Room? get room => _room;
  bool get reconnecting => _reconnecting;
  bool get micOn => _micOn;
  bool get camOn => _camOn;
  DateTime? get joinedAt => _joinedAt;
  RecordingPhase get recordingPhase => _phase;
  String get requesterName => _requesterName;
  bool get hasRemote => _room?.remoteParticipants.isNotEmpty ?? false;

  /// Hay una grabación en curso en la sala (la ven las dos personas).
  bool get isRecording => _phase == RecordingPhase.recording || (_room?.isRecording ?? false);

  /// Algún video de la otra persona, si ya llegó.
  VideoTrack? get remoteVideo {
    final room = _room;
    if (room == null) return null;
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (t is VideoTrack && !pub.muted) return t;
      }
    }
    return null;
  }

  VideoTrack? get localVideo {
    final local = _room?.localParticipant;
    if (local == null) return null;
    for (final pub in local.videoTrackPublications) {
      final t = pub.track;
      if (t is VideoTrack && !pub.muted) return t;
    }
    return null;
  }

  bool get isNativeSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Cuelga la videollamada en curso (por ejemplo, cuando la otra persona ya terminó la llamada).
  void hangUp() => _closeScreen();

  // ---------------------------------------------------------------------------
  // Entrar a la llamada
  // ---------------------------------------------------------------------------

  /// Entra a la sala. Termina cuando la llamada se cierra, y entonces avisa con
  /// [onTerminated] (o [onInterrupted] si se cortó por un problema).
  Future<void> join({
    required String roomName,
    required String displayName,
    required String userId,
    required VoidCallback onTerminated,
    VoidCallback? onInterrupted,
  }) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) throw Exception('No se pudo abrir la pantalla de llamada.');

    _stopTimers();
    _roomName = roomName;
    _displayName = displayName;
    _interrupted = false;
    _reconnecting = false;
    _micOn = true;
    _camOn = true;
    _phase = RecordingPhase.idle;
    _egressId = null;

    final creds = await LiveKitApi.fetchToken(roomName: roomName, displayName: displayName);

    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    _listener = room.createListener();
    _attachListeners(room);
    room.addListener(notifyListeners);

    try {
      await room.connect(creds.url, creds.token);
    } catch (e, st) {
      debugPrint('LiveKit: falló la conexión a ${creds.url}: $e\n$st');
      await _teardown();
      throw Exception('No se pudo conectar con LiveKit ($e).');
    }

    // Si la cámara o el micrófono fallan (por ejemplo, en un emulador), la llamada sigue.
    try {
      await room.localParticipant?.setMicrophoneEnabled(true);
    } catch (e, st) {
      debugPrint('LiveKit: no se pudo abrir el micrófono: $e\n$st');
      _micOn = false;
      CallNotice.show('No se pudo abrir el micrófono.', vibrate: false);
    }
    try {
      await room.localParticipant?.setCameraEnabled(true);
    } catch (e, st) {
      debugPrint('LiveKit: no se pudo abrir la cámara: $e\n$st');
      _camOn = false;
      CallNotice.show('No se pudo abrir la cámara.', vibrate: false);
    }

    _joinedAt = DateTime.now();
    _startBreakTimer();

    _closed = Completer<void>();
    final route = MaterialPageRoute<void>(builder: (_) => LiveKitCallScreen(service: this));
    _route = route;
    navigator.push<void>(route).whenComplete(() {
      if (!(_closed?.isCompleted ?? true)) _closed!.complete();
    });
    await _closed!.future;

    final wasInterrupted = _interrupted;
    await _teardown();
    if (wasInterrupted && onInterrupted != null) {
      onInterrupted();
    } else {
      onTerminated();
    }
  }

  void _attachListeners(Room room) {
    _listener!
      ..on<ParticipantConnectedEvent>((_) {
        _aloneTimer?.cancel();
        notifyListeners();
      })
      // Si la otra persona se va y nadie vuelve en unos segundos, esta llamada también termina.
      ..on<ParticipantDisconnectedEvent>((_) {
        notifyListeners();
        if (room.remoteParticipants.isEmpty) {
          _aloneTimer?.cancel();
          _aloneTimer = Timer(_aloneGrace, _closeScreen);
        }
      })
      ..on<RoomReconnectingEvent>((_) {
        _reconnecting = true;
        notifyListeners();
      })
      ..on<RoomReconnectedEvent>((_) {
        _reconnecting = false;
        notifyListeners();
      })
      // Si se desconecta por algo distinto a colgar, la llamada queda "interrumpida" (RF35).
      ..on<RoomDisconnectedEvent>((event) {
        if (event.reason != DisconnectReason.clientInitiated) _interrupted = true;
        _closeScreen();
      })
      ..on<DataReceivedEvent>(_onData)
      ..on<RoomRecordingStatusChanged>((event) {
        if (!event.activeRecording && _phase == RecordingPhase.recording) {
          _phase = RecordingPhase.idle;
          _egressId = null;
        }
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((_) => notifyListeners())
      ..on<TrackUnsubscribedEvent>((_) => notifyListeners())
      ..on<TrackMutedEvent>((_) => notifyListeners())
      ..on<TrackUnmutedEvent>((_) => notifyListeners());
  }

  /// Cierra la pantalla de llamada; `join` se encarga del resto.
  void _closeScreen() {
    _aloneTimer?.cancel();
    final route = _route;
    _route = null;
    if (route != null) appNavigatorKey.currentState?.removeRoute(route);
    if (!(_closed?.isCompleted ?? true)) _closed!.complete();
  }

  Future<void> _teardown() async {
    _stopTimers();
    await _stopRecordingIfNeeded();
    final room = _room;
    _room = null;
    _phase = RecordingPhase.idle;
    _joinedAt = null;
    room?.removeListener(notifyListeners);
    await _listener?.dispose();
    _listener = null;
    try {
      await room?.disconnect();
      await room?.dispose();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Micrófono y cámara
  // ---------------------------------------------------------------------------

  Future<void> toggleMic() async {
    _micOn = !_micOn;
    notifyListeners();
    await _room?.localParticipant?.setMicrophoneEnabled(_micOn);
  }

  Future<void> toggleCamera() async {
    _camOn = !_camOn;
    notifyListeners();
    await _room?.localParticipant?.setCameraEnabled(_camOn);
  }

  // ---------------------------------------------------------------------------
  // Pausa sugerida (RF36)
  // ---------------------------------------------------------------------------

  String _breakMessage(int minutes) {
    final unit = minutes == 1 ? 'minuto' : 'minutos';
    return 'Llevan $minutes $unit conversando. Si quieren, pueden tomar una pausa. La llamada continúa.';
  }

  void _startBreakTimer() {
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(kBreakSuggestionAfter, (timer) {
      final minutes = kBreakSuggestionAfter.inMinutes * timer.tick;
      final message = _breakMessage(minutes);
      CallNotice.show(message);
      Future.delayed(const Duration(seconds: 4), () => CallNotice.show(message, vibrate: false));
    });
  }

  void _stopTimers() {
    _aloneTimer?.cancel();
    _breakTimer?.cancel();
  }

  // ---------------------------------------------------------------------------
  // Grabación con consentimiento de las dos personas
  //
  //  1. Quien quiere grabar pulsa "Grabar" -> se envía una solicitud a la otra persona.
  //  2. La otra persona ve un aviso y acepta o rechaza.
  //  3. Solo si acepta, quien pidió inicia la grabación. Las dos ven el indicador "REC".
  //  4. Cualquiera de las dos puede detenerla cuando quiera.
  // ---------------------------------------------------------------------------

  Future<void> _send(Map<String, String> message) async {
    await _room?.localParticipant?.publishData(
      utf8.encode(jsonEncode(message)),
      reliable: true,
    );
  }

  /// Quien pulsa "Grabar".
  Future<void> requestRecording() async {
    if (_phase != RecordingPhase.idle) return;
    if (!hasRemote) {
      CallNotice.show('Esperen a que la otra persona se conecte para poder grabar.', vibrate: false);
      return;
    }
    _phase = RecordingPhase.waitingAnswer;
    notifyListeners();
    await _send({'t': 'rec_request', 'name': _displayName});
  }

  /// Respuesta de quien recibió la solicitud.
  Future<void> answerRecording({required bool accept}) async {
    if (_phase != RecordingPhase.askingMe) return;
    _phase = RecordingPhase.idle;
    notifyListeners();
    await _send({'t': accept ? 'rec_accept' : 'rec_decline'});
  }

  /// Detener: la pide cualquiera; la detiene quien la inició.
  Future<void> stopRecording() async {
    if (_phase == RecordingPhase.waitingAnswer) {
      _phase = RecordingPhase.idle;
      notifyListeners();
      await _send({'t': 'rec_cancel'});
      return;
    }
    if (_egressId != null) {
      await _stopRecordingIfNeeded();
      notifyListeners();
    } else if (isRecording) {
      await _send({'t': 'rec_stop'});
    }
  }

  Future<void> _stopRecordingIfNeeded() async {
    final id = _egressId;
    _egressId = null;
    if (id == null) return;
    try {
      await LiveKitApi.stopRecording(id);
    } catch (_) {
      // Si la sala se vacía, LiveKit termina la grabación por su cuenta.
    }
    _phase = RecordingPhase.idle;
  }

  Future<void> _onData(DataReceivedEvent event) async {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['t']) {
      case 'rec_request':
        if (_phase != RecordingPhase.idle) return;
        _requesterName = (msg['name'] as String?) ?? 'La otra persona';
        _phase = RecordingPhase.askingMe;
        notifyListeners();
        CallNotice.show('$_requesterName quiere grabar la llamada.');
      case 'rec_cancel':
        if (_phase == RecordingPhase.askingMe) {
          _phase = RecordingPhase.idle;
          notifyListeners();
        }
      case 'rec_decline':
        if (_phase == RecordingPhase.waitingAnswer) {
          _phase = RecordingPhase.idle;
          notifyListeners();
          CallNotice.show('La otra persona no aceptó grabar la llamada.', vibrate: false);
        }
      case 'rec_accept':
        if (_phase != RecordingPhase.waitingAnswer) return;
        _phase = RecordingPhase.starting;
        notifyListeners();
        try {
          _egressId = await LiveKitApi.startRecording(_roomName);
          _phase = RecordingPhase.recording;
        } catch (e) {
          _phase = RecordingPhase.idle;
          CallNotice.show('No se pudo iniciar la grabación.', vibrate: false);
        }
        notifyListeners();
      case 'rec_stop':
        if (_egressId != null) {
          await _stopRecordingIfNeeded();
          notifyListeners();
        }
    }
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}