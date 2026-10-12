import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/report_view.dart';
import 'package:vita_app/ui/features/shared/survey_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_schedule_view.dart';

class VolunteerHomeView extends StatefulWidget {
  const VolunteerHomeView({super.key});

  @override
  State<VolunteerHomeView> createState() => _VolunteerHomeViewState();
}

class _VolunteerHomeViewState extends State<VolunteerHomeView> {
  final _code = TextEditingController();
  Timer? _presence;

  @override
  void initState() {
    super.initState();
    // Latido: cada 20 s avisa que este celular sigue con la app abierta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) VitaScope.of(context).touchPresence();
    });
    _presence = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) VitaScope.of(context).touchPresence();
    });
  }

  @override
  void dispose() {
    _presence?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _joinIncoming(CallRequest request) async {
    final repo = VitaScope.of(context);
    await repo.acceptRequest(request.id);
    try {
      await repo.joinCurrentCall();
    } catch (e) {
      if (mounted) {
        await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SurveyView(request: request, askAccompanied: false)),
    );
  }

  Future<void> _joinCode() async {
    try {
      final request = await VitaScope.of(context).joinByCode(_code.text);
      await VitaScope.of(context).joinCurrentCall();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SurveyView(request: request, askAccompanied: false)),
      );
    } catch (e) {
      if (mounted) await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _emergency(CallRequest request) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Activar alerta?'),
        content: const Text('Se avisará a coordinación y quedará registro de la emergencia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await VitaScope.of(context).addAlert(
      callId: request.id,
      elderlyId: request.elderlyId,
      note: 'Alerta activada por el voluntario',
    );
    await showVitaMessage(context, 'Alerta registrada. Si hay riesgo vital, llama al 123.');
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) return const VitaPage(title: 'Voluntario', child: Text('Sesión cerrada'));
    final incoming = repo.requests.where((r) => r.volunteerId == user.id && r.status == CallRequestStatus.ringing).toList();
    final hours = repo.volunteerHours(user.id);

    return VitaPage(
      title: 'Hola, ${user.displayName}',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await repo.logout();
            if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ],
      child: ListView(
        children: [
          SwitchListTile(
            value: user.available,
            title: const Text('Estoy disponible'),
            onChanged: (value) async {
              try {
                await repo.setAvailability(value);
              } catch (e) {
                if (context.mounted) {
                  await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
                }
              }
            },
          ),
          Text('Horas de acompañamiento: ${hours.inMinutes} min'),
          const SizedBox(height: 16),
          if (incoming.isNotEmpty)
            Card(
              color: VitaColors.tint,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('¡Solicitud de llamada!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    VitaPrimaryButton(label: 'Aceptar', onPressed: () => _joinIncoming(incoming.first)),
                    const SizedBox(height: 8),
                    VitaPrimaryButton(
                      label: 'Rechazar',
                      color: Colors.grey,
                      onPressed: () => repo.rejectRequest(incoming.first.id),
                    ),
                    TextButton(
                      onPressed: () => _emergency(incoming.first),
                      child: const Text('Alerta de emergencia'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportView(request: incoming.first, reportedId: incoming.first.elderlyId),
                        ),
                      ),
                      child: const Text('Reportar'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Unirse con código (otro celular)'),
          const SizedBox(height: 8),
          TextField(controller: _code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Código de 4 dígitos')),
          const SizedBox(height: 8),
          VitaPrimaryButton(label: 'Unirme a la sala', color: VitaColors.secondary, onPressed: _joinCode),
          const SizedBox(height: 16),
          VitaPrimaryButton(
            label: 'Mis horarios',
            color: VitaColors.slate,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerScheduleView())),
          ),
        ],
      ),
    );
  }
}
