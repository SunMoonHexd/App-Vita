import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:vita_app/domain/call_health.dart';
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
  String? _reconnectMessage;
  bool _micOn = true;
  bool _camOn = true;
  bool _micNeedsRetry = false;
  bool _camNeedsRetry = false;
  bool _micChanging = false;
  bool _camChanging = false;
  DateTime? _joinedAt;
  Timer? _aloneTimer;
  Timer? _breakTimer;
  bool _micFailed = false;
  bool _camFailed = false;
  int? _micDevices;
  int? _camDevices;
  LinkQuality _lastQuality = LinkQuality.unknown;
  StreamSubscription<List<MediaDevice>>? _deviceSub;

  // Grabación
  RecordingPhase _phase = RecordingPhase.idle;
  String? _egressId;
  String _requesterName = '';
  String _displayName = '';
  String? _profilePhotoBase64;

  Room? get room => _room;
  bool get reconnecting => _reconnecting;
  String? get reconnectMessage => _reconnectMessage;
  bool get micOn => _micOn;
  bool get camOn => _camOn;
  bool get micNeedsRetry => _micNeedsRetry;
  bool get camNeedsRetry => _camNeedsRetry;
  DateTime? get joinedAt => _joinedAt;
  RecordingPhase get recordingPhase => _phase;
  String get requesterName => _requesterName;
  bool get hasRemote => _room?.remoteParticipants.isNotEmpty ?? false;
  String get localDisplayName => _displayName;
  String? get localPhotoBase64 => _profilePhotoBase64;
  String get remoteDisplayName =>
      _firstRemoteParticipant?.name ?? 'La otra persona';
  String? get remotePhotoBase64 {
    final metadata = _firstRemoteParticipant?.metadata;
    if (metadata == null || metadata.isEmpty) return null;
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is Map) return decoded['profilePhotoBase64'] as String?;
    } catch (_) {
      // Si la otra persona usa una versión anterior, mostramos sus iniciales.
    }
    return null;
  }

  DeviceHealth get micHealth => deviceHealth(
    wantedOn: _micOn,
    failed: _micFailed,
    devicesFound: _micDevices,
  );
  DeviceHealth get camHealth => deviceHealth(
    wantedOn: _camOn,
    failed: _camFailed,
    devicesFound: _camDevices,
  );
  bool get devicesNeedAttention =>
      needsAttention(micHealth) || needsAttention(camHealth);

  LinkQuality get linkQuality {
    final quality = _room?.localParticipant?.connectionQuality;
    if (quality == null) return LinkQuality.unknown;
    return LinkQuality.values.firstWhere(
      (value) => value.name == quality.name,
      orElse: () => LinkQuality.unknown,
    );
  }

  LinkStatus get linkStatus =>
      describeLink(linkQuality, reconnecting: _reconnecting);

  /// Estado publicado por la otra persona. `null` significa que aún no publicó
  /// una pista de ese tipo, así no se confunde con un dispositivo apagado.
  bool? get remoteMicOn {
    final participant = _firstRemoteParticipant;
    if (participant == null || participant.audioTrackPublications.isEmpty) {
      return null;
    }
    return participant.audioTrackPublications.any(
      (publication) => !publication.muted,
    );
  }

  bool? get remoteCamOn {
    final participant = _firstRemoteParticipant;
    if (participant == null || participant.videoTrackPublications.isEmpty) {
      return null;
    }
    return participant.videoTrackPublications.any(
      (publication) => !publication.muted,
    );
  }

  RemoteParticipant? get _firstRemoteParticipant {
    final participants = _room?.remoteParticipants.values;
    return participants == null || participants.isEmpty
        ? null
        : participants.first;
  }

  /// Hay una grabación en curso en la sala (la ven las dos personas).
  bool get isRecording =>
      _phase == RecordingPhase.recording || (_room?.isRecording ?? false);

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
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Cuelga la videollamada en curso (por ejemplo, cuando la otra persona ya terminó la llamada).
  void hangUp() => _closeScreen();

  // ---------------------------------------------------------------------------
  // Entrar a la llamada
  // ---------------------------------------------------------------------------

  /// Entra a la sala. Termina cuando la llamada se cierra, y entonces avisa con
  /// [onTerminated] (o [onInterrupted] si se cortó por un problema).
  Future<void> join({
    required String roomName,
    required String requestId,
    required String displayName,
    required String userId,
    String? profilePhotoBase64,
    required VoidCallback onTerminated,
    VoidCallback? onInterrupted,
  }) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null)
      throw Exception('No se pudo abrir la pantalla de llamada.');

    _stopTimers();
    _roomName = roomName;
    _displayName = displayName;
    _profilePhotoBase64 = profilePhotoBase64;
    _interrupted = false;
    _reconnecting = false;
    _reconnectMessage = null;
    _micOn = true;
    _camOn = true;
    _micNeedsRetry = false;
    _camNeedsRetry = false;
    _micChanging = false;
    _camChanging = false;
    _micFailed = false;
    _camFailed = false;
    _micDevices = null;
    _camDevices = null;
    _lastQuality = LinkQuality.unknown;
    _phase = RecordingPhase.idle;
    _egressId = null;

    final creds = await LiveKitApi.fetchToken(
      roomName: roomName,
      requestId: requestId,
      displayName: displayName,
    );

    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    _listener = room.createListener();
    _attachListeners(room);
    room.addListener(notifyListeners);

    try {
      await room.connect(creds.url, creds.token);
      final photo = profilePhotoBase64;
      if (photo != null && photo.isNotEmpty) {
        unawaited(
          room.localParticipant
                  ?.setMetadata(jsonEncode({'profilePhotoBase64': photo}))
                  .catchError((Object error) {
                    debugPrint(
                      'LiveKit: no se pudo compartir la foto en esta llamada: $error',
                    );
                  }) ??
              Future<void>.value(),
        );
      }
    } catch (e, st) {
      debugPrint('LiveKit: falló la conexión a ${creds.url}: $e\n$st');
      await _teardown();
      throw Exception('No se pudo conectar con LiveKit ($e).');
    }

    // Si falla un dispositivo, la llamada sigue y se ofrecen reintentos (F6.12).
    final micOk = await _openDevice(mic: true, delays: const []);
    final camOk = await _openDevice(mic: false, delays: const []);
    if (!micOk || !camOk) {
      CallNotice.show(
        !micOk && !camOk
            ? 'No se pudo abrir el micrófono ni la cámara. Reintentando…'
            : (!micOk
                  ? 'No se pudo abrir el micrófono. Reintentando…'
                  : 'No se pudo abrir la cámara. Reintentando…'),
        vibrate: false,
      );
      unawaited(_retryFailedInBackground());
    }
    unawaited(_watchDevices());

    _joinedAt = DateTime.now();
    _startBreakTimer();

    _closed = Completer<void>();
    final route = MaterialPageRoute<void>(
      builder: (_) => LiveKitCallScreen(service: this),
    );
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
        _startAloneTimerIfNeeded(room);
      })
      ..on<RoomReconnectingEvent>((_) {
        _aloneTimer?.cancel();
        _reconnecting = true;
        _reconnectMessage = 'Reconectando audio y video…';
        notifyListeners();
      })
      ..on<RoomResumingEvent>((_) {
        _aloneTimer?.cancel();
        _reconnecting = true;
        _reconnectMessage = 'Restableciendo la conexión…';
        notifyListeners();
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        _aloneTimer?.cancel();
        _reconnecting = true;
        _reconnectMessage =
            'Reconectando… (${event.attempt}/${event.maxAttemptsRetry})';
        notifyListeners();
      })
      ..on<RoomReconnectedEvent>((_) {
        _reconnecting = false;
        _reconnectMessage = null;
        notifyListeners();
        _startAloneTimerIfNeeded(room);
      })
      // Si se desconecta por algo distinto a colgar, la llamada queda "interrumpida" (RF35).
      ..on<RoomDisconnectedEvent>((event) {
        _reconnecting = false;
        _reconnectMessage = null;
        if (event.reason != DisconnectReason.clientInitiated)
          _interrupted = true;
        _closeScreen();
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        if (event.participant is LocalParticipant) _onLocalQuality(linkQuality);
        notifyListeners();
      })
      ..on<ParticipantMetadataUpdatedEvent>((_) => notifyListeners())
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
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted);
  }

  void _onTrackMuted(TrackMutedEvent event) {
    _updateLocalTrackState(
      event.participant,
      event.publication.kind,
      muted: true,
    );
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    _updateLocalTrackState(
      event.participant,
      event.publication.kind,
      muted: false,
    );
  }

  void _updateLocalTrackState(
    Participant participant,
    TrackType kind, {
    required bool muted,
  }) {
    if (participant == _room?.localParticipant) {
      switch (kind) {
        case TrackType.AUDIO:
          _micOn = !muted;
          if (!muted) _micNeedsRetry = false;
          break;
        case TrackType.VIDEO:
          _camOn = !muted;
          if (!muted) _camNeedsRetry = false;
          break;
        case TrackType.DATA:
          break;
      }
    }
    notifyListeners();
  }

  void _startAloneTimerIfNeeded(Room room) {
    if (room.remoteParticipants.isEmpty) {
      _aloneTimer?.cancel();
      _aloneTimer = Timer(_aloneGrace, _closeScreen);
    }
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
    await _deviceSub?.cancel();
    _deviceSub = null;
    await _stopRecordingIfNeeded();
    final room = _room;
    _room = null;
    _reconnecting = false;
    _reconnectMessage = null;
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

  Future<bool> _openDevice({
    required bool mic,
    List<Duration> delays = kDeviceRetryDelays,
  }) async {
    final room = _room;
    final success = await tryWithRetries(() async {
      final local = _room?.localParticipant;
      if (room == null || !identical(_room, room) || local == null) {
        throw StateError('La llamada ya terminó.');
      }
      if (mic) {
        await local.setMicrophoneEnabled(true);
      } else {
        await local.setCameraEnabled(true);
      }
    }, delays: delays);
    if (room == null || !identical(_room, room)) return false;
    if (mic) {
      _micFailed = !success;
      _micOn = success;
      _micNeedsRetry = !success;
    } else {
      _camFailed = !success;
      _camOn = success;
      _camNeedsRetry = !success;
    }
    if (!success)
      debugPrint(
        'LiveKit: no se pudo abrir ${mic ? 'el micrófono' : 'la cámara'}.',
      );
    notifyListeners();
    return success;
  }

  Future<void> _retryFailedInBackground() async {
    if (_micFailed && await _openDevice(mic: true)) {
      CallNotice.show('El micrófono ya funciona.', vibrate: false);
    }
    if (_camFailed && await _openDevice(mic: false)) {
      CallNotice.show('La cámara ya funciona.', vibrate: false);
    }
    if (_room != null && devicesNeedAttention) {
      CallNotice.show(
        'Algún dispositivo no abrió. Toca «Reintentar» en la pantalla.',
        vibrate: false,
      );
    }
  }

  Future<void> retryDevices() async {
    if (_micFailed) await _openDevice(mic: true, delays: const []);
    if (_camFailed) await _openDevice(mic: false, delays: const []);
    if (_room != null && !devicesNeedAttention) {
      CallNotice.show('Cámara y micrófono funcionando.', vibrate: false);
    }
  }

  Future<void> _watchDevices() async {
    await _deviceSub?.cancel();
    _deviceSub = null;
    try {
      _updateDevices(
        await Hardware.instance.enumerateDevices(),
        announce: false,
      );
      _deviceSub = Hardware.instance.onDeviceChange.stream.listen(
        (devices) => _updateDevices(devices, announce: true),
      );
    } catch (e) {
      debugPrint('LiveKit: no se pudieron revisar los dispositivos: $e');
    }
  }

  void _updateDevices(List<MediaDevice> devices, {required bool announce}) {
    if (_room == null) return;
    final microphones = devices
        .where((device) => device.kind == 'audioinput')
        .length;
    final cameras = devices
        .where((device) => device.kind == 'videoinput')
        .length;
    if (announce) {
      if (_micDevices != null && microphones < _micDevices!) {
        CallNotice.show(
          'Se desconectó un dispositivo de audio.',
          vibrate: false,
        );
      }
      if (_camDevices != null && cameras < _camDevices!) {
        CallNotice.show('Se desconectó una cámara.', vibrate: false);
      }
    }
    _micDevices = microphones;
    _camDevices = cameras;
    notifyListeners();
  }

  void _onLocalQuality(LinkQuality quality) {
    if (isWeakLink(quality) && !isWeakLink(_lastQuality)) {
      CallNotice.show(
        'Tu conexión está débil. Si se corta, podrás volver a llamar.',
        vibrate: false,
      );
    }
    _lastQuality = quality;
  }

  Future<void> toggleMic() async {
    await _setMicrophoneEnabled(!_micOn);
  }

  Future<void> toggleCamera() async {
    await _setCameraEnabled(!_camOn);
  }

  Future<void> retryMicrophone() async {
    if (!_micNeedsRetry) return;
    await _setMicrophoneEnabled(true);
  }

  Future<void> retryCamera() async {
    if (!_camNeedsRetry) return;
    await _setCameraEnabled(true);
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    if (_micChanging) return;
    final participant = _room?.localParticipant;
    if (participant == null) {
      CallNotice.show(
        'La conexión aún no está lista para cambiar el micrófono.',
        vibrate: false,
      );
      return;
    }

    _micChanging = true;
    try {
      await participant.setMicrophoneEnabled(enabled);
      _micOn = enabled;
      _micFailed = enabled ? false : _micFailed;
      if (enabled) _micNeedsRetry = false;
    } catch (e, st) {
      debugPrint('LiveKit: no se pudo cambiar el micrófono: $e\n$st');
      if (enabled) {
        _micNeedsRetry = true;
        _micFailed = true;
      }
      final action = enabled ? 'activar' : 'silenciar';
      CallNotice.show(
        'No se pudo $action el micrófono. Revisa el dispositivo.',
        vibrate: false,
      );
    } finally {
      _micChanging = false;
      notifyListeners();
    }
  }

  Future<void> _setCameraEnabled(bool enabled) async {
    if (_camChanging) return;
    final participant = _room?.localParticipant;
    if (participant == null) {
      CallNotice.show(
        'La conexión aún no está lista para cambiar la cámara.',
        vibrate: false,
      );
      return;
    }

    _camChanging = true;
    try {
      await participant.setCameraEnabled(enabled);
      _camOn = enabled;
      _camFailed = enabled ? false : _camFailed;
      if (enabled) _camNeedsRetry = false;
    } catch (e, st) {
      debugPrint('LiveKit: no se pudo cambiar la cámara: $e\n$st');
      if (enabled) {
        _camNeedsRetry = true;
        _camFailed = true;
      }
      final action = enabled ? 'activar' : 'apagar';
      CallNotice.show(
        'No se pudo $action la cámara. Revisa el dispositivo.',
        vibrate: false,
      );
    } finally {
      _camChanging = false;
      notifyListeners();
    }
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
      Future.delayed(
        const Duration(seconds: 4),
        () => CallNotice.show(message, vibrate: false),
      );
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
      CallNotice.show(
        'Esperen a que la otra persona se conecte para poder grabar.',
        vibrate: false,
      );
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
          CallNotice.show(
            'La otra persona no aceptó grabar la llamada.',
            vibrate: false,
          );
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
