import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/elderly/elderly_home_view.dart';

class ElderlyRegisterView extends StatefulWidget {
  const ElderlyRegisterView({super.key});

  @override
  State<ElderlyRegisterView> createState() => _ElderlyRegisterViewState();
}

class _ElderlyRegisterViewState extends State<ElderlyRegisterView> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _familyName = TextEditingController();
  final _familyPhone = TextEditingController();
  final _altName = TextEditingController();
  final _altPhone = TextEditingController();
  DateTime? _birth;
  bool _consent = false;
  bool _aptitude = false;
  bool _familyAdult = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    _familyName.dispose();
    _familyPhone.dispose();
    _altName.dispose();
    _altPhone.dispose();
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 70),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _submit() async {
    if (_birth == null) {
      setState(() => _error = 'Indica tu fecha de nacimiento.');
      return;
    }
    if (!_familyAdult) {
      setState(() => _error = 'El familiar de contacto debe ser mayor de 18 años.');
      return;
    }
    final result = await VitaScope.of(context).registerElderly(
      name: _name.text,
      birthDate: _birth!,
      phone: _phone.text,
      pin: _pin.text,
      familyName: _familyName.text,
      familyPhone: _familyPhone.text,
      alternateName: _altName.text,
      alternatePhone: _altPhone.text,
      consent: _consent,
      aptitude: _aptitude,
    );
    if (!mounted) return;
    if (!result.isOk) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ElderlyHomeView()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Registro',
      child: ListView(
        children: [
          const Text(termsText),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre y apellidos')),
          const SizedBox(height: 12),
          ListTile(
            title: Text(_birth == null ? 'Fecha de nacimiento' : '${_birth!.day}/${_birth!.month}/${_birth!.year}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickBirth,
          ),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          const SizedBox(height: 12),
          TextField(controller: _pin, maxLength: 4, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN de 4 dígitos')),
          TextField(controller: _familyName, decoration: const InputDecoration(labelText: 'Nombre del familiar')),
          const SizedBox(height: 12),
          TextField(controller: _familyPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono del familiar')),
          const SizedBox(height: 12),
          TextField(controller: _altName, decoration: const InputDecoration(labelText: 'Contacto alternativo')),
          const SizedBox(height: 12),
          TextField(controller: _altPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono alternativo')),
          CheckboxListTile(
            value: _familyAdult,
            onChanged: (v) => setState(() => _familyAdult = v ?? false),
            title: const Text('Confirmo que el familiar es mayor de 18 años'),
          ),
          CheckboxListTile(
            value: _aptitude,
            onChanged: (v) => setState(() => _aptitude = v ?? false),
            title: const Text('Puedo usar la aplicación de forma autónoma'),
          ),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text(consentText),
          ),
          VitaErrorText(_error),
          VitaPrimaryButton(label: 'Crear cuenta', onPressed: _submit),
        ],
      ),
    );
  }
}
