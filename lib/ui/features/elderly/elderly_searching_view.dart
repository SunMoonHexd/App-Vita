import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/report_view.dart';
import 'package:vita_app/ui/features/shared/survey_view.dart';

class ElderlySearchingView extends StatefulWidget {
  const ElderlySearchingView({super.key});

  @override
  State<ElderlySearchingView> createState() => _ElderlySearchingViewState();
}

class _ElderlySearchingViewState extends State<ElderlySearchingView> {
  CallRequest? _request;
  String? _error;
  Timer? _ringTimer;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final request = await VitaScope.of(context).startCallRequest();
      if (!mounted) return;
      setState(() => _request = request);
      _watch(request);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _watch(CallRequest request) {
    _ringTimer?.cancel();
    switch (request.status) {
      case CallRequestStatus.expired:
        setState(() => _error = 'No hay voluntarios disponibles ahora.');
      case CallRequestStatus.cancelled:
        Navigator.pop(context);
      case CallRequestStatus.connected:
        _enterCall();
      case CallRequestStatus.ringing:
        _ringTimer = Timer(VitaRepositoryTimes.ring, () async {
          if (!mounted) return;
          final repo = VitaScope.of(context);
          if (request.volunteerId == 'volunteer-demo') {
            final accepted = await repo.autoAcceptDemo(request.id);
            if (!mounted) return;
            setState(() => _request = accepted);
            _watch(accepted);
            return;
          }
          final next = await repo.timeoutRing(request.id);
          if (!mounted) return;
          setState(() => _request = next);
          _watch(next);
        });
      case CallRequestStatus.searching:
      case CallRequestStatus.completed:
      case CallRequestStatus.interrupted:
        break;
    }
  }

  Future<void> _enterCall() async {
    if (_joining) return;
    setState(() => _joining = true);
    final repo = VitaScope.of(context);
    try {
      await repo.joinCurrentCall();
    } catch (e) {
      if (mounted) {
        await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
    if (!mounted) return;
    final request = repo.requests.cast<CallRequest?>().firstWhere(
          (r) => r?.id == _request?.id,
          orElse: () => _request,
        );
    if (request != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurveyView(request: request, askAccompanied: true),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancel() async {
    final id = _request?.id;
    if (id != null) await VitaScope.of(context).cancelRequest(id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _help() {
    return showVitaMessage(
      context,
      'Activa el micrófono, sube el volumen y permite la cámara. La llamada no se corta al leer esta ayuda.',
    );
  }

  Future<void> _emergency() async {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    final request = _request;
    if (user == null || request == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Llamar a tu familiar?'),
        content: const Text('Se cerrará la búsqueda o la llamada y se abrirá el marcador.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, llamar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await repo.addAlert(callId: request.id, elderlyId: user.id, note: 'Botón de emergencia del adulto mayor');
    await repo.finishCall(request.id, status: CallRequestStatus.interrupted);
    final phone = user.familyPhone;
    if (phone != null) {
      await launchUrl(Uri.parse('tel:$phone'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return VitaPage(
      title: 'Buscando voluntario',
      child: Column(
        children: [
          if (_error != null) ...[
            VitaErrorText(_error),
            VitaPrimaryButton(label: 'Volver', onPressed: () => Navigator.pop(context)),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              request?.status == CallRequestStatus.connected
                  ? 'Conectando la videollamada...'
                  : 'Estamos buscando a alguien para acompañarte.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (request != null) Text('Código para el voluntario: ${request.joinCode}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Si el voluntario está en otro celular, que ingrese este código.'),
            const Spacer(),
            VitaPrimaryButton(label: 'Cancelar búsqueda', color: Colors.grey.shade700, onPressed: _cancel),
            const SizedBox(height: 12),
            VitaPrimaryButton(label: 'Ayuda', icon: Icons.help, color: Colors.indigo, onPressed: _help),
            const SizedBox(height: 12),
            VitaPrimaryButton(label: 'Emergencia', icon: Icons.emergency, color: Colors.red.shade700, onPressed: _emergency),
            if (request?.volunteerId != null)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportView(request: request!, reportedId: request.volunteerId!),
                  ),
                ),
                child: const Text('Reportar'),
              ),
          ],
        ],
      ),
    );
  }
}

class VitaRepositoryTimes {
  static const ring = Duration(seconds: 8);
}
