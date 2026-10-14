import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class CoordinatorHomeView extends StatelessWidget {
  const CoordinatorHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final pending = repo.users.where((u) => u.role == UserRole.volunteer && u.status == AccountStatus.pending).toList();
    final avg = repo.averageDuration;

    return VitaPage(
      title: 'Panel coordinación',
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
          Text('Llamadas completadas: ${repo.completedCalls}'),
          Text('Duración promedio: ${avg.inMinutes} min'),
          const SizedBox(height: 12),
          VitaPrimaryButton(
            label: 'Restablecer PIN de un adulto',
            color: VitaColors.secondary,
            onPressed: () => _resetPin(context),
          ),
          const Divider(),
          const Text('Voluntarios pendientes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          if (pending.isEmpty) const Text('No hay solicitudes nuevas.'),
          for (final user in pending)
            ListTile(
              title: Text(user.displayName),
              subtitle: Text('${user.email} · ${user.documentId}'),
              trailing: Wrap(
                children: [
                  IconButton(icon: const Icon(Icons.check, color: VitaColors.secondary), onPressed: () => repo.approveVolunteer(user.id, approve: true)),
                  IconButton(icon: const Icon(Icons.close, color: VitaColors.alert), onPressed: () => repo.approveVolunteer(user.id, approve: false)),
                ],
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
          for (final alert in repo.alerts) _AlertCard(alert: alert),
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

/// Alerta de emergencia con el contacto del familiar a un toque (RF11).
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final EmergencyAlert alert;

  /// Deja solo los dígitos y, si son 10 (celular colombiano), antepone el 57.
  String _international(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ? '57$digits' : digits;
  }

  @override
  Widget build(BuildContext context) {
    final elderly = VitaScope.of(context).userById(alert.elderlyId);
    final familyPhone = elderly?.familyPhone;
    final altPhone = elderly?.alternatePhone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency, color: VitaColors.alert),
                const SizedBox(width: 8),
                Expanded(child: Text(alert.note ?? 'Alerta', style: const TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
            Text('${elderly?.displayName ?? 'Adulto mayor'} · ${alert.createdAt.toLocal()}'),
            if (familyPhone != null && familyPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Familiar: ${elderly?.familyName ?? ''} · $familyPhone'),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar al familiar'),
                    onPressed: () => launchUrl(Uri.parse('tel:$familyPhone')),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    onPressed: () => launchUrl(
                      Uri.parse('https://wa.me/${_international(familyPhone)}'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
            if (altPhone != null && altPhone.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.call),
                label: Text('Contacto alternativo: ${elderly?.alternateName ?? ''} · $altPhone'),
                onPressed: () => launchUrl(Uri.parse('tel:$altPhone')),
              ),
          ],
        ),
      ),
    );
  }
}
