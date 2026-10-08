import 'package:flutter/material.dart';
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

  static const days = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    final slots = user == null ? [] : repo.slotsFor(user.id);

    return VitaPage(
      title: 'Mis horarios',
      child: ListView(
        children: [
          DropdownButton<int>(
            value: _weekday,
            isExpanded: true,
            items: [
              for (final entry in days.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) => setState(() => _weekday = v ?? 1),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _start,
                  items: [
                    for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('Desde $h:00')),
                  ],
                  onChanged: (v) => setState(() => _start = v ?? 8),
                ),
              ),
              Expanded(
                child: DropdownButton<int>(
                  value: _end,
                  items: [
                    for (var h = 1; h <= 24; h++) DropdownMenuItem(value: h, child: Text('Hasta $h:00')),
                  ],
                  onChanged: (v) => setState(() => _end = v ?? 12),
                ),
              ),
            ],
          ),
          VitaPrimaryButton(
            label: 'Guardar franja',
            onPressed: () async {
              try {
                await repo.addSlot(weekday: _weekday, startHour: _start, endHour: _end);
              } catch (e) {
                if (context.mounted) {
                  await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
                }
              }
            },
          ),
          const SizedBox(height: 16),
          for (final slot in slots)
            ListTile(
              title: Text('${days[slot.weekday]} · ${slot.startHour}:00 a ${slot.endHour}:00'),
              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => repo.removeSlot(slot.id)),
            ),
        ],
      ),
    );
  }
}
