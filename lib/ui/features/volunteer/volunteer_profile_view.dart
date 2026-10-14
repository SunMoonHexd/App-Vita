import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

/// RF14: el voluntario edita su teléfono y su contraseña, confirmando con su contraseña actual.
class VolunteerProfileView extends StatefulWidget {
  const VolunteerProfileView({super.key});

  @override
  State<VolunteerProfileView> createState() => _VolunteerProfileViewState();
}

class _VolunteerProfileViewState extends State<VolunteerProfileView> {
  late final TextEditingController _phone;
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  var _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _phone = TextEditingController(text: VitaScope.of(context).currentUser?.phone);
  }

  @override
  void dispose() {
    _phone.dispose();
    _current.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  int _digits(String text) => text.replaceAll(RegExp(r'\D'), '').length;

  Future<void> _save() async {
    if (_digits(_phone.text) < 7) {
      await showVitaMessage(context, 'Revisa tu número de teléfono.');
      return;
    }
    if (_newPassword.text.isNotEmpty && _newPassword.text.length < 6) {
      await showVitaMessage(context, 'La contraseña nueva debe tener al menos 6 caracteres.');
      return;
    }
    if (_current.text.isEmpty) {
      await showVitaMessage(context, 'Escribe tu contraseña actual para guardar los cambios.');
      return;
    }
    final repo = VitaScope.of(context);
    setState(() => _saving = true);
    try {
      await repo.verifyPassword(_current.text);
      await repo.updateProfile(phone: _phone.text.trim());
      if (_newPassword.text.isNotEmpty) {
        await repo.changeVolunteerPassword(currentPassword: _current.text, newPassword: _newPassword.text);
      }
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
      title: 'Mis datos',
      child: ListView(
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña nueva (opcional)',
              helperText: 'Déjala vacía si no quieres cambiarla.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña actual',
              helperText: 'La pedimos para confirmar que eres tú.',
            ),
          ),
          const SizedBox(height: 24),
          VitaPrimaryButton(label: _saving ? 'Guardando…' : 'Guardar', onPressed: _saving ? null : _save),
        ],
      ),
    );
  }
}
