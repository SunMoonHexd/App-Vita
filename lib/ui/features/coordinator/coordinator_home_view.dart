import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/domain/emergency_followup.dart';
import 'package:vita_app/domain/volunteer_verification.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/theme_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/coordinator/privacy_admin_view.dart';

class CoordinatorHomeView extends StatelessWidget {
  const CoordinatorHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final pending = repo.users.where((u) => u.role == UserRole.volunteer && u.status == AccountStatus.pending).toList();
    final presentationReviews = repo.users.where((u) => u.role == UserRole.volunteer && u.volunteerPresentationConsent && !u.volunteerPresentationReviewed && u.status != AccountStatus.blocked).toList();
    final identityReviews = repo.users.where((u) => u.role == UserRole.volunteer && u.status == AccountStatus.active && !u.identityVerified && u.idFrontBase64 != null && u.idBackBase64 != null && u.photoBase64 != null).toList();
    final avg = repo.averageDuration;

    return VitaPage(
      title: 'Panel coordinación',
      actions: [
        IconButton(
          tooltip: 'Privacidad y seguridad',
          icon: const Icon(Icons.shield_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PrivacyAdminView()),
          ),
        ),
        IconButton(
          tooltip: 'Apariencia',
          icon: const Icon(Icons.brightness_6_rounded),
          onPressed: () => showVitaThemeSheet(context),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await repo.logout();
            if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ],
      child: ListView(
        children: [
          Text('Llamadas completadas: ${repo.completedCalls}'),
          Text('Duración promedio: ${avg.inMinutes} min'),
          const SizedBox(height: 12),
          VitaPrimaryButton(
            label: 'Restablecer PIN de un adulto',
            color: VitaColors.secondary,
            onPressed: () => _resetPin(context),
          ),
          const SizedBox(height: 10),
          VitaPrimaryButton(
            label: 'Crear profesional de apoyo',
            color: VitaColors.secondary,
            onPressed: () => _createPsychologist(context),
          ),
          const Divider(),
          const Text('Apoyo psicológico', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          if (repo.supportRequests.isEmpty) const Text('Aún no hay solicitudes de apoyo.'),
          for (final r in (repo.supportRequests.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt))).take(10))
            ListTile(
              title: Text('${_supportLabel(r.status)} · ${r.createdAt.toLocal().toString().substring(0, 16)}'),
              subtitle: Text(
                'Pidió: ${repo.userById(r.requestedById)?.displayName ?? '—'}\n'
                'Profesional: ${r.psychologistId == null ? 'sin asignar' : (repo.userById(r.psychologistId!)?.displayName ?? '—')}',
              ),
              isThreeLine: true,
            ),
          const Divider(),
          const Text('Voluntarios pendientes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          if (pending.isEmpty) const Text('No hay solicitudes nuevas.'),
          for (final user in pending)
            ListTile(
              title: Text(user.displayName),
              subtitle: Text(_pendingDetails(user)),
              isThreeLine: true,
              trailing: Wrap(
                children: [
                  // RF3: solo se puede aprobar con el correo verificado.
                  IconButton(
                    tooltip: user.identityVerified ? 'Cédula verificada' : 'Revisar cédula',
                    icon: Icon(user.identityVerified ? Icons.verified_user : Icons.badge_outlined),
                    color: user.identityVerified ? VitaColors.success : context.vita.muted,
                    onPressed: user.idFrontBase64 == null || user.idBackBase64 == null || user.photoBase64 == null
                        ? null
                        : () => _reviewIdentityDocuments(context, user),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.check,
                      color: canApproveVolunteer(user) ? context.vita.accentBlue : context.vita.muted,
                    ),
                    onPressed: canApproveVolunteer(user) ? () => repo.approveVolunteer(user.id, approve: true) : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.vita.dangerTone.fg),
                    onPressed: () => repo.approveVolunteer(user.id, approve: false),
                  ),
                ],
              ),
            ),
          const Divider(),
          const Text('Cédulas pendientes de revisión', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          if (identityReviews.isEmpty) const Text('No hay cédulas de voluntarios activos pendientes.'),
          for (final user in identityReviews)
            ListTile(
              title: Text(user.displayName),
              subtitle: Text('${user.email ?? ''} · documento ${user.documentId ?? 'sin dato'}'),
              trailing: TextButton.icon(
                onPressed: () => _reviewIdentityDocuments(context, user),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Revisar'),
              ),
            ),
          const Divider(),
          const Text('Presentaciones para revisar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const Text('Solo se publican si el voluntario autorizó y coordinación aprueba el contenido.'),
          if (presentationReviews.isEmpty) const Text('No hay presentaciones pendientes.'),
          for (final user in presentationReviews)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (user.volunteerBio.isNotEmpty) Text(user.volunteerBio),
                  if (user.volunteerInterests.isNotEmpty) Text('Intereses: ${user.volunteerInterests}'),
                  if (user.volunteerExperience.isNotEmpty) Text('Experiencia: ${user.volunteerExperience}'),
                  Text(user.photoBase64 == null ? 'Sin foto' : 'Incluye foto para publicación'),
                  Align(alignment: Alignment.centerRight, child: Wrap(children: [
                    TextButton(onPressed: () => repo.reviewVolunteerPresentation(user.id, approve: false), child: const Text('Rechazar')),
                    FilledButton(onPressed: () => repo.reviewVolunteerPresentation(user.id, approve: true), child: const Text('Aprobar publicación')),
                  ])),
                ]),
              ),
            ),
          const Divider(),
          const Text('Reportes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          for (final report in repo.reports)
            ListTile(
              title: Text(report.reason),
              subtitle: Text(
                'Reportado: ${repo.userById(report.reportedId)?.displayName ?? 'desconocido'} '
                '(cuenta ${repo.userById(report.reportedId)?.status.name ?? '-'})\n'
                'Estado: ${report.status.name}\n${report.comment ?? ''}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<Object>(
                onSelected: (value) {
                  if (value == 'review') {
                    repo.suspendWhileReviewing(report.id);
                  } else if (value == 'reactivate') {
                    repo.setAccountStatus(report.reportedId, AccountStatus.active);
                  } else if (value is ReportStatus) {
                    repo.resolveReport(report.id, value);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<Object>(value: 'review', child: Text('Suspender mientras se revisa')),
                  PopupMenuItem<Object>(value: ReportStatus.archived, child: Text('Archivar')),
                  PopupMenuItem<Object>(value: ReportStatus.warned, child: Text('Advertir')),
                  PopupMenuItem<Object>(value: ReportStatus.suspended, child: Text('Suspender')),
                  PopupMenuItem<Object>(value: ReportStatus.blocked, child: Text('Bloquear')),
                  PopupMenuItem<Object>(value: 'reactivate', child: Text('Reactivar cuenta')),
                ],
              ),
            ),
          const Divider(),
          const Text('Cuentas suspendidas o bloqueadas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          if (repo.users.every((u) => u.status != AccountStatus.suspended && u.status != AccountStatus.blocked))
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No hay cuentas suspendidas ni bloqueadas.')),
          for (final user in repo.users.where((u) => u.status == AccountStatus.suspended || u.status == AccountStatus.blocked))
            ListTile(
              title: Text(user.displayName),
              subtitle: Text('${user.role.name} · ${user.status.name}'),
              trailing: TextButton(
                onPressed: () => repo.setAccountStatus(user.id, AccountStatus.active),
                child: const Text('Reactivar'),
              ),
            ),
          const Divider(),
          const Text('Alertas de emergencia', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          for (final alert in sortAlerts(repo.alerts)) _AlertCard(alert: alert),
          const Divider(),
          const Text('Historial de llamadas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          for (final call in repo.requests.reversed)
            ListTile(
              title: Text(call.status.name),
              subtitle: Text(
                '${call.createdAt.toLocal()}\nSala ${call.roomName} · ${call.duration.inMinutes} min',
              ),
              isThreeLine: true,
            ),
        ],
      ),
    );
  }

  static String _supportLabel(SupportStatus s) => switch (s) {
        SupportStatus.open => 'Abierta',
        SupportStatus.accepted => 'En curso',
        SupportStatus.closed => 'Cerrada',
        SupportStatus.cancelled => 'Cancelada',
      };

  Future<void> _createPsychologist(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear profesional de apoyo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Verifica antes su identidad y su título. Recibirá un correo para elegir su contraseña.',
            ),
            const SizedBox(height: 12),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre completo')),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await VitaScope.of(context).createPsychologist(name: name.text, email: email.text);
      if (context.mounted) {
        await showVitaMessage(context, 'Cuenta creada. Le enviamos un correo para que elija su contraseña.');
      }
    } catch (e) {
      if (context.mounted) {
        await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _resetPin(BuildContext context) async {
    final phone = TextEditingController();
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Verifica la identidad del adulto o del familiar y define un PIN nuevo de 4 dígitos.'),
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono del adulto')),
            TextField(controller: pin, maxLength: 4, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'PIN nuevo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restablecer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await VitaScope.of(context).coordinatorResetElderlyPin(phone: phone.text.trim(), newPin: pin.text.trim());
      if (context.mounted) {
        await showVitaMessage(context, 'PIN restablecido. El adulto ya puede ingresar.');
      }
    } catch (e) {
      if (context.mounted) {
        await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }
}

Future<void> _reviewIdentityDocuments(BuildContext context, VitaUser user) async {
  final front = user.idFrontBase64;
  final back = user.idBackBase64;
  if (front == null || back == null) return;
  final verified = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Cédula de ${user.displayName}'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Compara la foto personal con la cédula. Confirma que las imágenes pertenecen a la misma persona.'),
          if (user.photoBase64 != null) ...[
            const SizedBox(height: 12),
            const Text('Foto personal'),
            CircleAvatar(radius: 52, backgroundImage: MemoryImage(base64Decode(user.photoBase64!))),
          ],
          const SizedBox(height: 12),
          const Text('Frente'),
          Image.memory(base64Decode(front), fit: BoxFit.contain),
          const SizedBox(height: 8),
          const Text('Reverso'),
          Image.memory(base64Decode(back), fit: BoxFit.contain),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cerrar')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Marcar identidad verificada')),
      ],
    ),
  );
  if (verified == true && context.mounted) {
    try {
      await VitaScope.of(context).verifyVolunteerIdentity(user.id);
      if (context.mounted) await showVitaMessage(context, 'Identidad verificada. Ya puedes aprobar la cuenta del voluntario.');
    } catch (e) {
      if (context.mounted) await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

/// Alerta de emergencia con su seguimiento paso a paso (RF11 · F8.7, F8.9 y F8.11).
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final EmergencyAlert alert;

  static String _when(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  static String _hour(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  /// Abre WhatsApp o el marcador y, si se pudo abrir, deja anotado que se avisó.
  Future<void> _contact(
    BuildContext context, {
    required bool family,
    required String phone,
    required bool whatsapp,
    required String message,
  }) async {
    final repo = VitaScope.of(context);
    final uri = whatsapp
        ? Uri.https('wa.me', '/${internationalPhone(phone)}', {'text': message})
        : Uri.parse('tel:$phone');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) return;
    final channel = whatsapp ? 'whatsapp' : 'llamada';
    if (family) {
      await repo.notifyFamily(alert.id, channel: channel);
    } else {
      await repo.notifyAlternate(alert.id, channel: channel);
    }
  }

  Future<void> _close(BuildContext context) async {
    final repo = VitaScope.of(context);
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar alerta'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Nota de cierre (opcional)',
            helperText: 'Qué pasó y quién se hizo cargo.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Cerrar alerta'),
          ),
        ],
      ),
    );
    if (note != null) await repo.resolveAlert(alert.id, note: note);
  }

  Widget _panel(
    VitaToneColors tone,
    String title,
    List<Widget> actions, {
    String? detail,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: tone.fg)),
          if (detail != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: actions),
        ],
      ),
    );
  }

  Widget _stepPanel(
    BuildContext context,
    EmergencyStep step, {
    required VitaUser? elderly,
    required String familyPhone,
    required String alternatePhone,
    required String message,
    required VitaToneColors tone,
  }) {
    final repo = VitaScope.of(context);
    final familyName = (elderly?.familyName ?? '').trim().isEmpty ? 'Familiar' : elderly!.familyName!;
    final alternateName = (elderly?.alternateName ?? '').trim().isEmpty ? 'Contacto alternativo' : elderly!.alternateName!;

    List<Widget> contactButtons({required bool family, required String phone}) => [
          FilledButton.icon(
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp'),
            onPressed: () => _contact(context, family: family, phone: phone, whatsapp: true, message: message),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.call),
            label: const Text('Llamar'),
            onPressed: () => _contact(context, family: family, phone: phone, whatsapp: false, message: message),
          ),
        ];

    String channelOf(String? channel) => channel == 'whatsapp' ? 'WhatsApp' : 'llamada';

    return switch (step) {
      EmergencyStep.contactFamily => _panel(
          tone,
          'Paso 1 · Avisar al familiar',
          contactButtons(family: true, phone: familyPhone),
          detail: '$familyName · $familyPhone',
        ),
      EmergencyStep.awaitFamily => _panel(
          tone,
          'Se avisó al familiar por ${channelOf(alert.familyChannel)} a las ${_hour(alert.familyNotifiedAt)}. ¿Respondió?',
          [
            FilledButton(
              onPressed: () => repo.setFamilyOutcome(alert.id, FamilyOutcome.reached),
              child: const Text('Sí, respondió'),
            ),
            OutlinedButton(
              onPressed: () => repo.setFamilyOutcome(alert.id, FamilyOutcome.noAnswer),
              child: const Text('No contestó'),
            ),
          ],
          detail: '$familyName · $familyPhone',
        ),
      EmergencyStep.contactAlternate => _panel(
          tone,
          'Paso 2 · Avisar al contacto alternativo',
          contactButtons(family: false, phone: alternatePhone),
          detail: '$alternateName · $alternatePhone',
        ),
      EmergencyStep.awaitAlternate => _panel(
          tone,
          'Se avisó al contacto alternativo a las ${_hour(alert.alternateNotifiedAt)}. ¿Respondió?',
          [
            FilledButton(
              onPressed: () => repo.setAlternateOutcome(alert.id, FamilyOutcome.reached),
              child: const Text('Sí, respondió'),
            ),
            OutlinedButton(
              onPressed: () => repo.setAlternateOutcome(alert.id, FamilyOutcome.noAnswer),
              child: const Text('No contestó'),
            ),
          ],
          detail: '$alternateName · $alternatePhone',
        ),
      EmergencyStep.escalate => _panel(
          tone,
          'Familiar no localizable',
          [
            FilledButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('Llamar al 123'),
              onPressed: () => launchUrl(Uri.parse('tel:123'), mode: LaunchMode.externalApplication),
            ),
            OutlinedButton(onPressed: () => _close(context), child: const Text('Cerrar alerta')),
          ],
          detail: 'No se logró hablar con el familiar ni con el contacto alternativo. '
              'Llama al 123 o pide una visita al domicilio, y anota lo que se hizo al cerrar.',
        ),
      EmergencyStep.readyToClose => _panel(
          tone,
          alert.familyOutcome == FamilyOutcome.reached
              ? 'Se logró hablar con el familiar'
              : 'Se logró hablar con el contacto alternativo',
          [FilledButton(onPressed: () => _close(context), child: const Text('Cerrar alerta'))],
        ),
      EmergencyStep.closed => _panel(
          tone,
          'Atendida el ${_when(alert.resolvedAt ?? alert.createdAt)}',
          const [],
          detail: alert.resolutionNote,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final vita = context.vita;
    final elderly = repo.userById(alert.elderlyId);
    final elderlyName = elderly?.displayName ?? 'Un adulto mayor';
    final familyPhone = (elderly?.familyPhone ?? '').trim();
    final alternatePhone = (elderly?.alternatePhone ?? '').trim();
    final step = nextEmergencyStep(
      alert,
      hasFamilyPhone: familyPhone.isNotEmpty,
      hasAlternatePhone: alternatePhone.isNotEmpty,
    );
    final message = buildFamilyMessage(elderlyName: elderlyName, when: alert.createdAt);
    final closed = alert.status == AlertStatus.resolved;
    final tone = closed
        ? vita.successTone
        : (step == EmergencyStep.escalate ? vita.dangerTone : vita.warningTone);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(closed ? Icons.check_circle : Icons.emergency, color: tone.fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.note ?? 'Alerta de emergencia',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                _StatusChip(status: alert.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              alert.isAnonymized
                  ? 'Datos anonimizados · ${_when(alert.createdAt)}'
                  : '$elderlyName · ${_when(alert.createdAt)}',
              style: TextStyle(color: vita.muted),
            ),
            if (!alert.isAnonymized) ...[
              const SizedBox(height: 10),
              _stepPanel(
                context,
                step,
                elderly: elderly,
                familyPhone: familyPhone,
                alternatePhone: alternatePhone,
                message: message,
                tone: tone,
              ),
              if (!closed)
                Row(
                  children: [
                    if (alert.status == AlertStatus.open)
                      TextButton(onPressed: () => repo.takeAlert(alert.id), child: const Text('Tomar alerta')),
                    if (step != EmergencyStep.escalate && step != EmergencyStep.readyToClose)
                      TextButton(onPressed: () => _close(context), child: const Text('Cerrar alerta')),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Etiqueta con el estado de la alerta (F8.11).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final vita = context.vita;
    final (label, tone) = switch (status) {
      AlertStatus.open => ('Abierta', vita.dangerTone),
      AlertStatus.inProgress => ('En atención', vita.warningTone),
      AlertStatus.resolved => ('Atendida', vita.successTone),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: tone.fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Datos que coordinación revisa de un voluntario pendiente (RF3).
String _pendingDetails(VitaUser user) {
  final birth = user.birthDate;
  final birthText = birth == null
      ? 'Sin fecha de nacimiento'
      : 'Nació el ${birth.day}/${birth.month}/${birth.year} (${ageOn(birth, DateTime.now())} años)';
  final emailText = user.emailVerified ? 'Correo verificado' : 'Correo sin verificar: no se puede aprobar todavía';
  final identityText = user.identityVerified
      ? 'Cédula revisada: identidad verificada'
      : (user.idFrontBase64 != null && user.idBackBase64 != null
          ? 'Cédula cargada: falta revisión de coordinación'
          : 'Falta frente o reverso de la cédula');
  final photoText = user.photoBase64 == null ? 'Falta foto personal' : 'Foto personal lista para comparar';
  return '${user.email} · ${user.documentId}\n$birthText\n$emailText\n$identityText\n$photoText';
}
