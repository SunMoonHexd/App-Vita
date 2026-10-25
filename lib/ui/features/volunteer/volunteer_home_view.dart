import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/data/services/volunteer_push_notifications.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/report_view.dart';
import 'package:vita_app/ui/features/shared/survey_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_format.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_help_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_hours_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_profile_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_reports_view.dart';
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
      if (!mounted) return;
      final repo = VitaScope.of(context);
      repo.touchPresence();
      final user = repo.currentUser;
      if (user != null && user.available) _registerPushForAvailableVolunteer(user.id);
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

  Future<void> _registerPushForAvailableVolunteer(String userId) async {
    try {
      final registered = await VolunteerPushNotifications.instance
          .registerVolunteer(userId);
      if (registered || !mounted) return;
      await VitaScope.of(context).setAvailability(false);
      if (mounted) {
        await showVitaMessage(
          context,
          'Activa las notificaciones para recibir solicitudes cuando VITA esté minimizada.',
        );
      }
    } catch (error) {
      if (mounted) {
        await showVitaMessage(
          context,
          'No se pudieron activar los avisos de llamadas: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
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
    if (!mounted) return;
    // RF11: se registra la alerta para coordinación y se ofrece marcar la línea 123.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alerta registrada'),
        content: const Text('Coordinación ya puede verla y avisar al familiar. Si hay riesgo vital, llama al 123.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          FilledButton(
            onPressed: () async {
              await launchUrl(Uri.parse('tel:123'));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Marcar 123'),
          ),
        ],
      ),
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) return const VitaPage(title: 'Voluntario', child: Text('Sesión cerrada'));

    final incoming =
        repo.requests.where((r) => r.volunteerId == user.id && r.status == CallRequestStatus.ringing).toList();
    final active = repo.requests.cast<CallRequest?>().firstWhere(
          (r) => r?.volunteerId == user.id && r?.status == CallRequestStatus.connected,
          orElse: () => null,
        );

    // Resumen: llamadas de hoy y tiempo acompañando esta semana.
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    var todayCalls = 0;
    var week = Duration.zero;
    for (final r in repo.requests) {
      if (r.volunteerId != user.id || r.status != CallRequestStatus.completed) continue;
      final started = (r.startedAt ?? r.createdAt).toLocal();
      if (!started.isBefore(startOfToday)) todayCalls++;
      if (!started.isBefore(startOfWeek)) week += r.duration;
    }

    final firstName = shortName(user.displayName, fallback: 'voluntario');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            VitaHeader(
              eyebrow: 'Panel de voluntario',
              title: 'Hola, $firstName',
              badge: const Align(
                alignment: Alignment.centerLeft,
                child: VitaPill(label: 'Voluntario verificado', tone: VitaTone.success, icon: Icons.verified_rounded),
              ),
              trailing: Semantics(
                button: true,
                label: 'Mi perfil',
                child: GestureDetector(
                  onTap: () => _open(const VolunteerProfileView()),
                  child: VitaAvatar(name: user.displayName, size: 54, photoBase64: user.photoBase64),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  if (incoming.isNotEmpty) ...[
                    _IncomingCard(
                      onAccept: () => _joinIncoming(incoming.first),
                      onReject: () => repo.rejectRequest(incoming.first.id),
                      onEmergency: () => _emergency(incoming.first),
                      onReport: () => _open(ReportView(request: incoming.first, reportedId: incoming.first.elderlyId)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // RF11: durante una llamada en curso, el voluntario puede activar la alerta o reportar.
                  if (active != null) ...[
                    _ActiveCallCard(
                      onEmergency: () => _emergency(active),
                      onReport: () => _open(ReportView(request: active, reportedId: active.elderlyId)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  VitaCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mi disponibilidad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(
                                  user.available
                                      ? 'Recibirás avisos aunque minimices VITA. Desactiva tu disponibilidad al terminar.'
                                      : 'No recibirás solicitudes',
                                  style: TextStyle(fontSize: 16, color: context.vita.muted, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: user.available,
                            onChanged: (value) async {
                              try {
                                if (value) {
                                  final registered =
                                      await VolunteerPushNotifications.instance
                                          .registerVolunteer(user.id);
                                  if (!registered) {
                                    if (context.mounted) {
                                      await showVitaMessage(
                                        context,
                                        'Permite las notificaciones para poder recibir solicitudes cuando VITA esté minimizada.',
                                      );
                                    }
                                    return;
                                  }
                                }
                                await repo.setAvailability(value);
                              } catch (e) {
                                if (context.mounted) {
                                  await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: VitaStatTile(
                          icon: Icons.phone_in_talk_rounded,
                          label: 'Hoy',
                          value: todayCalls == 1 ? '1 llamada' : '$todayCalls llamadas',
                          tone: VitaTone.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: VitaStatTile(
                          icon: Icons.timer_outlined,
                          label: 'Esta semana',
                          value: formatDuration(week),
                          tone: VitaTone.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  VitaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                          child: Text('ACCESOS RÁPIDOS', style: VitaText.overline.copyWith(color: context.vita.muted)),
                        ),
                        _QuickRow(emoji: '🗓️', label: 'Mis turnos', onTap: () => _open(const VolunteerScheduleView())),
                        const Divider(height: 1),
                        _QuickRow(emoji: '⏱️', label: 'Mis horas', onTap: () => _open(const VolunteerHoursView())),
                        const Divider(height: 1),
                        _QuickRow(emoji: '📋', label: 'Mis reportes', onTap: () => _open(const VolunteerReportsView())),
                        const Divider(height: 1),
                        _QuickRow(emoji: '❓', label: 'Ayuda', onTap: () => _open(const VolunteerHelpView())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Respaldo: unirse a la sala de un adulto con el código de 6 dígitos.
                  VitaCard(
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        title: const Text(
                          '¿Tienes un código? Unirse a una sala',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        children: [
                          TextField(
                            controller: _code,
                            maxLength: 6,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Código de 6 dígitos', counterText: ''),
                          ),
                          const SizedBox(height: 10),
                          VitaPrimaryButton(
                            label: 'Unirme a la sala',
                            color: VitaColors.secondary,
                            onPressed: _joinCode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: VitaNavBar(
        items: const [
          VitaNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio'),
          VitaNavItem(icon: Icons.event_outlined, selectedIcon: Icons.event_rounded, label: 'Turnos'),
          VitaNavItem(icon: Icons.timer_outlined, selectedIcon: Icons.timer_rounded, label: 'Mis horas'),
          VitaNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Perfil'),
        ],
        onSelected: (index) {
          if (index == 1) _open(const VolunteerScheduleView());
          if (index == 2) _open(const VolunteerHoursView());
          if (index == 3) _open(const VolunteerProfileView());
        },
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Icon(Icons.chevron_right_rounded, color: context.vita.muted),
          ],
        ),
      ),
    );
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.onAccept,
    required this.onReject,
    required this.onEmergency,
    required this.onReport,
  });

  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEmergency;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: VitaGradients.primary(),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: VitaColors.primaryLight.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          const Text('📞', style: TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          const Text(
            '¡Solicitud de llamada!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'Un adulto mayor quiere conversar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: Colors.white),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: VitaColors.primary,
                elevation: 0,
              ),
              child: const Text('Aceptar'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.7), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              child: const Text('Rechazar'),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onEmergency,
                child: const Text('Alerta de emergencia'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onReport,
                child: const Text('Reportar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveCallCard extends StatelessWidget {
  const _ActiveCallCard({required this.onEmergency, required this.onReport});

  final VoidCallback onEmergency;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.vita.tint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.vita.tintBorder),
      ),
      child: Column(
        children: [
          const Text('Llamada en curso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: context.vita.dangerTone.fg),
                onPressed: onEmergency,
                child: const Text('Alerta de emergencia'),
              ),
              TextButton(onPressed: onReport, child: const Text('Reportar')),
            ],
          ),
        ],
      ),
    );
  }
}
