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
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: context.vita.tint, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.vita.tintBorder)),
            child: const Row(children: [
              Icon(Icons.volunteer_activism_outlined, color: VitaColors.primary, size: 27),
              SizedBox(width: 12),
              Expanded(child: Text('Aquí puedes ver el tiempo de tus llamadas completadas y revisar tu historial de acompañamiento.', style: TextStyle(height: 1.35))),
            ]),
          ),
          const SizedBox(height: 18),
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
                  _CallHistoryItem(
                    person: shortName(repo.userById(r.elderlyId)?.displayName ?? '', fallback: 'Adulto mayor'),
                    date: formatDateTime(r.startedAt ?? r.createdAt),
                    duration: formatDuration(r.duration),
                    completed: r.status == CallRequestStatus.completed,
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

class _CallHistoryItem extends StatelessWidget {
  const _CallHistoryItem({required this.person, required this.date, required this.duration, required this.completed});

  final String person;
  final String date;
  final String duration;
  final bool completed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: completed ? VitaColors.successBg : context.vita.warningTone.bg,
            child: Icon(completed ? Icons.call_made_rounded : Icons.call_missed_outgoing_rounded, color: completed ? VitaColors.success : context.vita.warningTone.fg),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(person, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 3),
            Text(date, style: TextStyle(color: context.vita.muted, fontSize: 13)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(duration, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(completed ? 'Completada' : 'Interrumpida', style: TextStyle(color: completed ? VitaColors.success : context.vita.warningTone.fg, fontSize: 12)),
          ]),
        ]),
      );
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
