import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _askRecordingPermission());
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, gracias')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, acepto')),
        ],
      ),
    );
    _askDialogOpen = false;
    await _s.answerRecording(accept: accept ?? false);
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
                    : _Waiting(connected: _s.hasRemote),
              ),
              // Barra superior: tiempo y grabación.
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _Pill(text: _elapsed(), icon: Icons.timer_outlined),
                    const Spacer(),
                    if (recording) const _Pill(text: 'REC', icon: Icons.fiber_manual_record, danger: true),
                  ],
                ),
              ),
              if (_s.reconnecting)
                const Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: Center(child: _Pill(text: 'Reconectando…', icon: Icons.wifi_off)),
                ),
              // Tu cámara.
              if (local != null)
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
                    _CallButton(
                      icon: _s.micOn ? Icons.mic : Icons.mic_off,
                      label: _s.micOn ? 'Micrófono' : 'Silenciado',
                      active: _s.micOn,
                      onTap: _s.toggleMic,
                    ),
                    _CallButton(
                      icon: _s.camOn ? Icons.videocam : Icons.videocam_off,
                      label: _s.camOn ? 'Cámara' : 'Sin cámara',
                      active: _s.camOn,
                      onTap: _s.toggleCamera,
                    ),
                    _recordButton(),
                    _CallButton(
                      icon: Icons.call_end,
                      label: 'Colgar',
                      color: VitaColors.alert,
                      onTap: () async => _s.hangUp(),
                    ),
                  ],
                  ),
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
        return const _CallButton(icon: Icons.hourglass_top, label: 'Iniciando…');
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
  const _Waiting({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 96, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            connected ? 'La otra persona tiene la cámara apagada' : 'Esperando a la otra persona…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ],
      ),
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
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
    this.color,
    this.active = true,
  });

  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;
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
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap == null ? null : () => onTap!(),
            child: SizedBox(width: 64, height: 64, child: Icon(icon, size: 30, color: foreground)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}