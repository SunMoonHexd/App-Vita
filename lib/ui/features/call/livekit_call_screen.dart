import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:vita_app/domain/call_health.dart';
import 'package:vita_app/data/services/call_notice.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';

/// Pantalla de videollamada: video de la otra persona, tu cámara pequeña y botones grandes.
class LiveKitCallScreen extends StatefulWidget {
  const LiveKitCallScreen({super.key, required this.service});

  final LiveKitCallService service;

  @override
  State<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends State<LiveKitCallScreen> {
  Timer? _clock;
  bool _askDialogOpen = false;

  LiveKitCallService get _s => widget.service;

  @override
  void initState() {
    super.initState();
    _s.addListener(_onChange);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _s.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_s.recordingPhase == RecordingPhase.askingMe && !_askDialogOpen) {
      _askDialogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _askRecordingPermission(),
      );
    }
  }

  Future<void> _askRecordingPermission() async {
    if (!mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¿Aceptas que se grabe la llamada?'),
        content: Text(
          '${_s.requesterName} quiere grabar esta videollamada. Mientras se grabe, '
          'las dos personas verán el aviso "REC". Puedes detenerla cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, gracias'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, acepto'),
          ),
        ],
      ),
    );
    _askDialogOpen = false;
    await _s.answerRecording(accept: accept ?? false);
  }

  /// Solo el voluntario lo ve: pedir (o cancelar) que un psicólogo se una a esta llamada.
  Widget _supportAction(BuildContext context) {
    final repo = VitaScope.of(context);
    final me = repo.currentUser;
    if (me == null || me.role != UserRole.volunteer)
      return const SizedBox.shrink();
    final call = repo.requests
        .where(
          (r) =>
              r.volunteerId == me.id && r.status == CallRequestStatus.connected,
        )
        .firstOrNull;
    if (call == null) return const SizedBox.shrink();
    final support = repo.activeSupportFor(call.id);
    final String label;
    final IconData icon;
    if (support == null) {
      label = 'Apoyo psicológico';
      icon = Icons.favorite_border_rounded;
    } else if (support.status == SupportStatus.open) {
      label = 'Buscando psicólogo…';
      icon = Icons.hourglass_top_rounded;
    } else {
      label = 'Psicólogo en camino';
      icon = Icons.check_circle_outline_rounded;
    }
    return GestureDetector(
      onTap: () => _onSupportTap(call, support),
      child: _Pill(text: label, icon: icon),
    );
  }

  Future<void> _onSupportTap(CallRequest call, SupportRequest? support) async {
    final repo = VitaScope.of(context);
    if (support == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Pedir apoyo psicológico?'),
          content: const Text(
            'Un profesional de apoyo recibirá el aviso y podrá unirse a esta llamada. '
            'Cuéntale a la persona con calma que alguien más va a acompañarlos, para que no se sorprenda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pedir apoyo'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await repo.requestPsychologistSupport(
          callId: call.id,
          note: 'El voluntario notó a la persona muy triste',
        );
        CallNotice.show(
          'Pedimos apoyo psicológico. Seguimos contigo en la llamada.',
          vibrate: false,
        );
      } catch (e) {
        CallNotice.show(
          e.toString().replaceFirst('Exception: ', ''),
          vibrate: false,
        );
      }
    } else if (support.status == SupportStatus.open) {
      final cancel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Estamos buscando un psicólogo'),
          content: const Text('¿Quieres cancelar la solicitud?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir esperando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar solicitud'),
            ),
          ],
        ),
      );
      if (cancel == true) await repo.cancelSupport(support.id);
    }
  }

  String _elapsed() {
    final start = _s.joinedAt;
    if (start == null) return '';
    final d = DateTime.now().difference(start);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final remote = _s.remoteVideo;
    final local = _s.localVideo;
    final recording = _s.isRecording;

    // Solo se sale con el botón rojo, no con el gesto de "atrás".
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: remote != null
                    ? VideoTrackRenderer(remote, fit: VideoViewFit.cover)
                    : _Waiting(
                        connected: _s.hasRemote,
                        cameraOn: _s.remoteCamOn,
                        name: _s.remoteDisplayName,
                        photoBase64: _s.remotePhotoBase64,
                        audioOnly: _s.audioOnly,
                      ),
              ),
              // Barra superior: tiempo y grabación.
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _Pill(text: _elapsed(), icon: Icons.timer_outlined),
                    const SizedBox(width: 8),
                    _supportAction(context),
                    const Spacer(),
                    if (recording)
                      const _Pill(
                        text: 'REC',
                        icon: Icons.fiber_manual_record,
                        danger: true,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 56,
                left: 12,
                child: _LinkPill(status: _s.linkStatus),
              ),
              // Tu cámara.
              if (_s.camOn && local != null)
                Positioned(
                  top: 56,
                  right: 12,
                  width: 104,
                  height: 144,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: VideoTrackRenderer(local, fit: VideoViewFit.cover),
                  ),
                ),
              if (!_s.camOn)
                Positioned(
                  top: 56,
                  right: 12,
                  width: 104,
                  height: 144,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF202124),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: VitaAvatar(
                        name: _s.localDisplayName,
                        size: 84,
                        photoBase64: _s.localPhotoBase64,
                      ),
                    ),
                  ),
                ),
              if (_s.devicesNeedAttention)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 140,
                  child: _DeviceBanner(
                    micHealth: _s.micHealth,
                    camHealth: _s.camHealth,
                    onRetry: _s.retryDevices,
                  ),
                ),
              // Botones grandes.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.only(top: 28, bottom: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _CallButton(
                          icon: _s.micOn ? Icons.mic : Icons.mic_off,
                          label: _s.micNeedsRetry
                              ? 'Reintentar'
                              : (_s.micOn ? 'Micrófono' : 'Silenciado'),
                          tooltip: _s.micNeedsRetry
                              ? 'Reintentar activar el micrófono'
                              : null,
                          active: _s.micOn,
                          onTap: _s.micNeedsRetry
                              ? _s.retryMicrophone
                              : _s.toggleMic,
                        ),
                      ),
                      Expanded(
                        child: _CallButton(
                          icon: _s.camOn ? Icons.videocam : Icons.videocam_off,
                          label: _s.camNeedsRetry
                              ? 'Reintentar'
                              : (_s.camOn ? 'Cámara' : 'Sin cámara'),
                          tooltip: _s.camNeedsRetry
                              ? 'Reintentar activar la cámara'
                              : null,
                          active: _s.camOn,
                          onTap: _s.camNeedsRetry
                              ? _s.retryCamera
                              : _s.toggleCamera,
                        ),
                      ),
                      Expanded(child: _recordButton()),
                      Expanded(
                        child: _CallButton(
                          icon: Icons.call_end,
                          label: 'Colgar',
                          color: VitaColors.alert,
                          onTap: () async => _s.hangUp(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_s.hasRemote)
                Positioned(
                  top: 100,
                  left: 12,
                  child: _MediaStatus(
                    microphoneOn: _s.remoteMicOn,
                    cameraOn: _s.remoteCamOn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordButton() {
    switch (_s.recordingPhase) {
      case RecordingPhase.waitingAnswer:
        return _CallButton(
          icon: Icons.hourglass_top,
          label: 'Esperando…',
          onTap: _s.stopRecording, // cancela la solicitud
        );
      case RecordingPhase.starting:
        return const _CallButton(
          icon: Icons.hourglass_top,
          label: 'Iniciando…',
        );
      default:
        if (_s.isRecording) {
          return _CallButton(
            icon: Icons.stop,
            label: 'Detener',
            color: VitaColors.alert,
            onTap: _s.stopRecording,
          );
        }
        return _CallButton(
          icon: Icons.fiber_manual_record,
          label: 'Grabar',
          onTap: _s.requestRecording,
        );
    }
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({
    required this.connected,
    required this.cameraOn,
    required this.name,
    required this.audioOnly,
    this.photoBase64,
  });

  final bool connected;
  final bool? cameraOn;
  final String name;
  final bool audioOnly;
  final String? photoBase64;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VitaAvatar(name: name, size: 144, photoBase64: photoBase64),
          const SizedBox(height: 16),
          Text(
            !connected
                ? 'Esperando a la otra persona…'
                : audioOnly && cameraOn != true
                ? 'Esta llamada es solo de voz'
                : cameraOn == false
                ? '$name tiene la cámara apagada'
                : 'Conectando el video de la otra persona…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _MediaStatus extends StatelessWidget {
  const _MediaStatus({required this.microphoneOn, required this.cameraOn});

  final bool? microphoneOn;
  final bool? cameraOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MediaStatusLine(
            icon: microphoneOn == true ? Icons.mic : Icons.mic_off,
            label: _statusLabel('Micrófono', microphoneOn),
            enabled: microphoneOn,
          ),
          const SizedBox(height: 5),
          _MediaStatusLine(
            icon: cameraOn == true ? Icons.videocam : Icons.videocam_off,
            label: _statusLabel('Cámara', cameraOn),
            enabled: cameraOn,
          ),
        ],
      ),
    );
  }

  String _statusLabel(String device, bool? enabled) {
    final isCamera = device == 'Cámara';
    return switch (enabled) {
      true => isCamera ? 'Cámara activa' : 'Micrófono activo',
      false => isCamera ? 'Cámara apagada' : 'Micrófono apagado',
      null => '$device sin datos',
    };
  }
}

class _MediaStatusLine extends StatelessWidget {
  const _MediaStatusLine({
    required this.icon,
    required this.label,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled == null
        ? Colors.white60
        : enabled!
        ? Colors.lightGreenAccent
        : Colors.orangeAccent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.icon, this.danger = false});

  final String text;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: danger ? VitaColors.alert : Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({required this.status});

  final LinkStatus status;

  IconData get _icon {
    if (status.bars == 0)
      return status.warn ? Icons.wifi_off : Icons.wifi_1_bar;
    if (status.bars == 1) return Icons.wifi_1_bar;
    if (status.bars == 2) return Icons.wifi_2_bar;
    return Icons.wifi;
  }

  @override
  Widget build(BuildContext context) =>
      _Pill(text: status.label, icon: _icon, danger: status.warn);
}

class _DeviceBanner extends StatelessWidget {
  const _DeviceBanner({
    required this.micHealth,
    required this.camHealth,
    required this.onRetry,
  });

  final DeviceHealth micHealth;
  final DeviceHealth camHealth;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final messages = <String>[
      if (needsAttention(micHealth)) deviceMessage(micHealth, mic: true),
      if (needsAttention(camHealth)) deviceMessage(camHealth, mic: false),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VitaColors.alert),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messages.join(' '),
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => onRetry(),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.tooltip,
    this.color,
    this.active = true,
  });

  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;
  final String? tooltip;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final background = color ?? (active ? Colors.white38 : Colors.white);
    final foreground = color != null || active ? Colors.white : Colors.black87;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          child: Tooltip(
            message: tooltip ?? label,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap == null ? null : () => onTap!(),
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(icon, size: 30, color: foreground),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
