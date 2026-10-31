import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class VolunteerPresentationView extends StatefulWidget {
  const VolunteerPresentationView({super.key});

  @override
  State<VolunteerPresentationView> createState() => _VolunteerPresentationViewState();
}

class _VolunteerPresentationViewState extends State<VolunteerPresentationView> {
  late final TextEditingController _bio;
  late final TextEditingController _interests;
  late final TextEditingController _experience;
  late bool _consent;
  bool _busy = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final user = VitaScope.of(context).currentUser!;
    _bio = TextEditingController(text: user.volunteerBio);
    _interests = TextEditingController(text: user.volunteerInterests);
    _experience = TextEditingController(text: user.volunteerExperience);
    _consent = user.volunteerPresentationConsent;
  }

  @override
  void dispose() {
    _bio.dispose();
    _interests.dispose();
    _experience.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await VitaScope.of(context).updateVolunteerPresentation(
        bio: _bio.text,
        interests: _interests.text,
        experience: _experience.text,
        consent: _consent,
      );
      if (!mounted) return;
      await showVitaMessage(context, _consent
          ? 'Presentación guardada. Coordinación debe revisarla antes de publicarla.'
          : 'Autorización retirada. Tu presentación dejará de mostrarse.');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) await showVitaMessage(context, 'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => VitaPage(
        title: 'Mi presentación',
        child: ListView(
          children: [
            const Text('La persona mayor verá esta información cuando VITA te asigne. Coordinación debe aprobarla antes de publicarla.'),
            const SizedBox(height: 16),
            TextField(controller: _bio, maxLength: 180, maxLines: 2, decoration: const InputDecoration(labelText: 'Presentación corta')),
            TextField(controller: _interests, maxLength: 160, decoration: const InputDecoration(labelText: 'Intereses')),
            TextField(controller: _experience, maxLength: 240, maxLines: 2, decoration: const InputDecoration(labelText: 'Experiencia de voluntariado')),
            CheckboxListTile(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Autorizo a VITA a mostrar mi nombre, foto y presentación al adulto mayor asignado, tras revisión de coordinación.'),
            ),
            const Text('La autorización es opcional y puedes retirarla cuando quieras. Al cambiar el contenido se oculta hasta que coordinación lo revise de nuevo.'),
            const SizedBox(height: 16),
            VitaPrimaryButton(label: _busy ? 'Guardando…' : 'Guardar presentación', onPressed: _busy ? null : _save),
          ],
        ),
      );
}
