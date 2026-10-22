import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/profile_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_format.dart';

/// Reportes que el voluntario ha hecho y en qué estado están.
class VolunteerReportsView extends StatelessWidget {
  const VolunteerReportsView({super.key});

  String _status(ReportStatus s) {
    switch (s) {
      case ReportStatus.pending:
        return 'En revisión';
      case ReportStatus.archived:
        return 'Archivado';
      case ReportStatus.warned:
        return 'Con advertencia';
      case ReportStatus.suspended:
        return 'Cuenta suspendida';
      case ReportStatus.blocked:
        return 'Cuenta bloqueada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) return const VitaPage(title: 'Mis reportes', child: Text('Sesión cerrada'));

    final mine = repo.reports.where((r) => r.reporterId == user.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return VitaPage(
      title: 'Mis reportes',
      child: ListView(
        children: [
          VitaCard(
            children: [
              const VitaCardTitle('REPORTES QUE HICE'),
              if (mine.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No has hecho reportes. Si algo en una llamada te parece raro, puedes reportarlo al recibir la solicitud o durante la llamada.',
                      style: TextStyle(fontSize: 17, color: context.vita.muted, height: 1.4),
                    ),
                  ),
                )
              else
                for (final r in mine) ...[
                  VitaDataRow(
                    emoji: '📋',
                    label: '${formatDateTime(r.createdAt)} · ${_status(r.status)}',
                    value:
                        '${shortName(repo.userById(r.reportedId)?.displayName ?? '', fallback: 'Persona reportada')} · ${r.reason}',
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                ],
              const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }
}
