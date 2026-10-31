import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class VolunteerScheduleView extends StatefulWidget {
  const VolunteerScheduleView({super.key});

  @override
  State<VolunteerScheduleView> createState() => _VolunteerScheduleViewState();
}

class _VolunteerScheduleViewState extends State<VolunteerScheduleView> {
  int _weekday = DateTime.now().weekday;
  int _start = 8;
  int _end = 12;
  bool _saving = false;

  static const days = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  String _time(int hour) {
    if (hour == 24) return '12:00 a. m.';
    if (hour == 0) return '12:00 a. m.';
    if (hour == 12) return '12:00 p. m.';
    if (hour < 12) return '$hour:00 a. m.';
    return '${hour - 12}:00 p. m.';
  }

  Future<void> _save() async {
    if (_end <= _start) {
      await showVitaMessage(context, 'Elige una hora final posterior a la hora de inicio.');
      return;
    }
    setState(() => _saving = true);
    try {
      await VitaScope.of(context).addSlot(weekday: _weekday, startHour: _start, endHour: _end);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Turno guardado para ${days[_weekday]}.')));
    } catch (e) {
      if (mounted) await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(String id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar este turno?'),
        content: Text('$label dejará de estar dentro de tu horario para recibir llamadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await VitaScope.of(context).removeSlot(id);
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    final slots = user == null ? [] : repo.slotsFor(user.id).toList()
      ..sort((a, b) => a.weekday != b.weekday ? a.weekday.compareTo(b.weekday) : a.startHour.compareTo(b.startHour));

    return VitaPage(
      title: 'Mis turnos',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.vita.tint, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.vita.tintBorder)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: VitaColors.primary),
              SizedBox(width: 10),
              Expanded(child: Text('Agrega los días y horas en que puedes recibir solicitudes. Usamos la hora de Colombia. Si no guardas turnos, podrás estar disponible a cualquier hora.', style: TextStyle(height: 1.4))),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('1. Elige el día', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final day in days.entries)
              ChoiceChip(label: Text(day.value), selected: _weekday == day.key, onSelected: (_) => setState(() => _weekday = day.key)),
          ]),
          const SizedBox(height: 20),
          const Text('2. Define el horario', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              value: _start,
              decoration: const InputDecoration(labelText: 'Desde', prefixIcon: Icon(Icons.play_arrow_rounded)),
              items: [for (var hour = 0; hour < 24; hour++) DropdownMenuItem(value: hour, child: Text(_time(hour)))],
              onChanged: (value) => setState(() { _start = value ?? _start; if (_end <= _start) _end = (_start + 1).clamp(1, 24).toInt(); }),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<int>(
              value: _end,
              decoration: const InputDecoration(labelText: 'Hasta', prefixIcon: Icon(Icons.stop_rounded)),
              items: [for (var hour = 1; hour <= 24; hour++) DropdownMenuItem(value: hour, child: Text(_time(hour)))],
              onChanged: (value) => setState(() => _end = value ?? _end),
            )),
          ]),
          const SizedBox(height: 14),
          VitaPrimaryButton(label: _saving ? 'Guardando…' : 'Agregar turno', icon: Icons.add_alarm_rounded, onPressed: _saving ? null : _save),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(child: Text('Tus turnos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            VitaPill(label: '${slots.length}', tone: VitaTone.info, icon: Icons.event_available_outlined),
          ]),
          const SizedBox(height: 10),
          if (slots.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: VitaColors.border)),
              child: const Column(children: [
                Icon(Icons.calendar_month_outlined, size: 38, color: VitaColors.primary),
                SizedBox(height: 8),
                Text('Todavía no tienes turnos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                SizedBox(height: 4),
                Text('Agrega uno arriba o deja la lista vacía para recibir solicitudes a cualquier hora.', textAlign: TextAlign.center),
              ]),
            )
          else
            for (final slot in slots)
              Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: context.vita.tint, child: const Icon(Icons.event_available_outlined, color: VitaColors.primary)),
                  title: Text(days[slot.weekday] ?? 'Día', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${_time(slot.startHour)} – ${_time(slot.endHour)}'),
                  trailing: IconButton(tooltip: 'Eliminar turno', icon: const Icon(Icons.delete_outline_rounded), color: context.vita.dangerTone.fg, onPressed: () => _remove(slot.id, '${days[slot.weekday]} ${_time(slot.startHour)} a ${_time(slot.endHour)}')),
                ),
              ),
        ],
      ),
    );
  }
}
