import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/profile_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_format.dart';

class VolunteerHoursView extends StatelessWidget {
  const VolunteerHoursView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) return const VitaPage(title: 'Mis horas', child: Text('Sesión cerrada'));

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month);

    final mine = repo.requests
        .where((r) =>
            r.volunteerId == user.id &&
            (r.status == CallRequestStatus.completed || r.status == CallRequestStatus.interrupted))
        .toList()
      ..sort((a, b) => (b.startedAt ?? b.createdAt).compareTo(a.startedAt ?? a.createdAt));

    var week = Duration.zero;
    var month = Duration.zero;
    var total = Duration.zero;
    for (final r in mine.where((r) => r.status == CallRequestStatus.completed)) {
      final started = (r.startedAt ?? r.createdAt).toLocal();
      total += r.duration;
      if (!started.isBefore(startOfWeek)) week += r.duration;
      if (!started.isBefore(startOfMonth)) month += r.duration;
    }

    return VitaPage(
      title: 'Mis horas',
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(child: _Total(label: 'Esta semana', value: formatDuration(week))),
              const SizedBox(width: 12),
              Expanded(child: _Total(label: 'Este mes', value: formatDuration(month))),
            ],
          ),
          const SizedBox(height: 12),
          _Total(label: 'Total acompañando', value: formatDuration(total), wide: true),
          const SizedBox(height: 22),
          VitaCard(
            children: [
              const VitaCardTitle('HISTORIAL DE LLAMADAS'),
              if (mine.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Aún no tienes llamadas. Cuando acompañes a alguien, aparecerán aquí.',
                      style: TextStyle(fontSize: 17, color: context.vita.muted, height: 1.4),
                    ),
                  ),
                )
              else
                for (final r in mine.take(50)) ...[
                  VitaDataRow(
                    emoji: r.status == CallRequestStatus.completed ? '📞' : '⚠️',
                    label:
                        '${formatDateTime(r.startedAt ?? r.createdAt)} · ${r.status == CallRequestStatus.completed ? 'Completada' : 'Interrumpida'}',
                    value:
                        '${shortName(repo.userById(r.elderlyId)?.displayName ?? '')} · ${formatDuration(r.duration)}',
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

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, this.wide = false});

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = VitaTone.info.resolve(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: context.vita.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: t.fg),
          ),
        ],
      ),
    );
  }
}
