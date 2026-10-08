import 'package:flutter/material.dart';
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
          const Divider(),
          const Text('Voluntarios pendientes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          if (pending.isEmpty) const Text('No hay solicitudes nuevas.'),
          for (final user in pending)
            ListTile(
              title: Text(user.displayName),
              subtitle: Text('${user.email} · ${user.documentId}'),
              trailing: Wrap(
                children: [
                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => repo.approveVolunteer(user.id, approve: true)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => repo.approveVolunteer(user.id, approve: false)),
                ],
              ),
            ),
          const Divider(),
          const Text('Reportes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          for (final report in repo.reports)
            ListTile(
              title: Text(report.reason),
              subtitle: Text('Estado: ${report.status.name}\n${report.comment ?? ''}'),
              isThreeLine: true,
              trailing: PopupMenuButton<ReportStatus>(
                onSelected: (status) => repo.resolveReport(report.id, status),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: ReportStatus.archived, child: Text('Archivar')),
                  PopupMenuItem(value: ReportStatus.warned, child: Text('Advertir')),
                  PopupMenuItem(value: ReportStatus.suspended, child: Text('Suspender')),
                  PopupMenuItem(value: ReportStatus.blocked, child: Text('Bloquear')),
                ],
              ),
            ),
          const Divider(),
          const Text('Alertas de emergencia', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          for (final alert in repo.alerts)
            ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: Text(alert.note ?? 'Alerta'),
              subtitle: Text(alert.createdAt.toLocal().toString()),
            ),
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
}
