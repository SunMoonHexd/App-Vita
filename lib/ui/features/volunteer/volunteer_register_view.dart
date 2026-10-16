import 'package:flutter/material.dart';
import 'package:vita_app/ui/features/shared/legal_text_view.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class VolunteerRegisterView extends StatefulWidget {
  const VolunteerRegisterView({super.key});

  @override
  State<VolunteerRegisterView> createState() => _VolunteerRegisterViewState();
}

class _VolunteerRegisterViewState extends State<VolunteerRegisterView> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _document = TextEditingController();
  DateTime? _birth;
  bool _consent = false;
  bool _conduct = false;
  bool _q1 = false;
  bool _q2 = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_birth == null) {
      setState(() => _error = 'Indica tu fecha de nacimiento.');
      return;
    }
    final result = await VitaScope.of(context).registerVolunteer(
      name: _name.text,
      birthDate: _birth!,
      phone: _phone.text,
      email: _email.text,
      password: _password.text,
      documentId: _document.text,
      consent: _consent,
      conduct: _conduct,
      inductionDone: _q1 && _q2,
    );
    if (!mounted) return;
    if (!result.isOk) {
      setState(() => _error = result.error);
      return;
    }
    await showVitaMessage(context, 'Cuenta creada. Te enviamos un correo para verificar tu dirección: toca el enlace. Después, coordinación revisará tu solicitud.');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Registro voluntario',
      child: ListView(
        children: [
          const Text(conductText),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre y apellidos')),
          ListTile(
            title: Text(_birth == null ? 'Fecha de nacimiento' : '${_birth!.day}/${_birth!.month}/${_birth!.year}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 25),
                firstDate: DateTime(1950),
                lastDate: now,
              );
              if (picked != null) setState(() => _birth = picked);
            },
          ),
          TextField(controller: _document, decoration: const InputDecoration(labelText: 'Documento')),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          CheckboxListTile(
            value: _q1,
            onChanged: (v) => setState(() => _q1 = v ?? false),
            title: const Text('Entiendo que el acompañamiento es social, no clínico.'),
          ),
          CheckboxListTile(
            value: _q2,
            onChanged: (v) => setState(() => _q2 = v ?? false),
            title: const Text('No pediré dinero, claves ni datos sensibles.'),
          ),
          CheckboxListTile(
            value: _conduct,
            onChanged: (v) => setState(() => _conduct = v ?? false),
            title: const Text('Acepto el código de conducta'),
          ),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text(
              'Acepto los términos de uso y la política de privacidad, y autorizo el tratamiento '
              'de mis datos personales (Ley 1581 de 2012).',
            ),
          ),
          const LegalLinks(),
          VitaErrorText(_error),
          VitaPrimaryButton(label: 'Crear cuenta', onPressed: _submit),
        ],
      ),
    );
  }
}
