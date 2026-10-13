import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/elderly/elderly_actions.dart';

class ElderlyEditProfileView extends StatefulWidget {
  const ElderlyEditProfileView({super.key});

  @override
  State<ElderlyEditProfileView> createState() => _ElderlyEditProfileViewState();
}

class _ElderlyEditProfileViewState extends State<ElderlyEditProfileView> {
  late final TextEditingController _phone;
  late final TextEditingController _familyName;
  late final TextEditingController _familyPhone;
  late final TextEditingController _altName;
  late final TextEditingController _altPhone;

  var _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final user = VitaScope.of(context).currentUser;
    _phone = TextEditingController(text: user?.phone);
    _familyName = TextEditingController(text: user?.familyName);
    _familyPhone = TextEditingController(text: user?.familyPhone);
    _altName = TextEditingController(text: user?.alternateName);
    _altPhone = TextEditingController(text: user?.alternatePhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    _familyName.dispose();
    _familyPhone.dispose();
    _altName.dispose();
    _altPhone.dispose();
    super.dispose();
  }

  int _digits(String text) => text.replaceAll(RegExp(r'\D'), '').length;

  /// Devuelve el mensaje de qué corregir, o null si todo está bien.
  String? _validate() {
    if (_familyName.text.trim().isEmpty) return 'Escribe el nombre de tu familiar responsable.';
    if (_digits(_familyPhone.text) < 7) return 'Revisa el teléfono de tu familiar.';
    final altName = _altName.text.trim();
    final altDigits = _digits(_altPhone.text);
    if (altName.isEmpty != (altDigits == 0)) {
      return 'Para el contacto alternativo escribe el nombre y el teléfono, o deja los dos vacíos.';
    }
    if (altDigits > 0 && altDigits < 7) return 'Revisa el teléfono del contacto alternativo.';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      await showVitaMessage(context, problem);
      return;
    }
    final confirmed = await confirmWithPin(
      context,
      title: 'Confirma con tu PIN',
      subtitle: 'Para guardar los cambios escribe tu PIN.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await VitaScope.of(context).updateProfile(
        phone: _phone.text.trim(),
        familyName: _familyName.text.trim(),
        familyPhone: _familyPhone.text.trim(),
        alternateName: _altName.text.trim(),
        alternatePhone: _altPhone.text.trim(),
      );
      if (!mounted) return;
      await showVitaMessage(context, 'Tus datos fueron actualizados.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Editar mis datos',
      child: ListView(
        children: [
          TextField(
            controller: _phone,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              helperText: 'Para cambiar tu número de ingreso, pide ayuda a coordinación.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _familyName, decoration: const InputDecoration(labelText: 'Familiar responsable')),
          const SizedBox(height: 16),
          TextField(
            controller: _familyPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono del familiar'),
          ),
          const SizedBox(height: 16),
          TextField(controller: _altName, decoration: const InputDecoration(labelText: 'Contacto alternativo')),
          const SizedBox(height: 16),
          TextField(
            controller: _altPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono del contacto alternativo'),
          ),
          const SizedBox(height: 24),
          VitaPrimaryButton(label: _saving ? 'Guardando...' : 'Guardar cambios', onPressed: _saving ? null : _save),
        ],
      ),
    );
  }
}
