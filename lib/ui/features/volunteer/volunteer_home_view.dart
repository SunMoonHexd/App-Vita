import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
      backgroundColor: VitaColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Panel de voluntario', style: TextStyle(fontSize: 16, color: VitaColors.muted)),
                        Text(
                          'Hola, $firstName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F5EA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF8BCFA3)),
                          ),
                          child: const Text(
                            '✓ Voluntario verificado',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E6B3F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _open(const VolunteerProfileView()),
                    child: VitaAvatar(name: user.displayName, size: 54),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
                  _Panel(
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
                                      ? 'Recibirás solicitudes. Deja esta pantalla abierta.'
                                      : 'No recibirás solicitudes',
                                  style: const TextStyle(fontSize: 16, color: VitaColors.muted, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: user.available,
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          emoji: '📞',
                          label: 'Hoy',
                          value: todayCalls == 1 ? '1 llamada' : '$todayCalls llamadas',
                          bg: const Color(0xFFE2F5F1),
                          border: const Color(0xFF9ED8CD),
                          color: VitaColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatTile(
                          emoji: '⏱️',
                          label: 'Esta semana',
                          value: formatDuration(week),
                          bg: const Color(0xFFE9F0FB),
                          border: const Color(0xFFC6D8F3),
                          color: VitaColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
                          child: Text(
                            'ACCESOS RÁPIDOS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: VitaColors.muted,
                            ),
                          ),
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
                  _Panel(
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: VitaColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const _NavItem(emoji: '🏠', label: 'Inicio', selected: true),
              _NavItem(emoji: '🗓️', label: 'Turnos', onTap: () => _open(const VolunteerScheduleView())),
              _NavItem(emoji: '⏱️', label: 'Mis horas', onTap: () => _open(const VolunteerHoursView())),
              _NavItem(emoji: '👤', label: 'Perfil', onTap: () => _open(const VolunteerProfileView())),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.bg,
    required this.border,
    required this.color,
  });

  final String emoji;
  final String label;
  final String value;
  final Color bg;
  final Color border;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 15, color: VitaColors.muted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        ],
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
            const Icon(Icons.chevron_right_rounded, color: VitaColors.muted),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.emoji, required this.label, this.onTap, this.selected = false});

  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? VitaColors.primary : VitaColors.ink,
                  ),
                ),
              ],
            ),
          ),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1FA596), Color(0xFF14877A)],
        ),
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
        color: VitaColors.tint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaColors.primaryLight),
      ),
      child: Column(
        children: [
          const Text('Llamada en curso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: VitaColors.alert),
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
