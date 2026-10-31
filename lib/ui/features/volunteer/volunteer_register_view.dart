import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _bio = TextEditingController();
  final _interests = TextEditingController();
  final _experience = TextEditingController();
  DateTime? _birth;
  bool _consent = false;
  bool _conduct = false;
  bool _q1 = false;
  bool _q2 = false;
  bool _presentationConsent = false;
  bool _identityConsent = false;
  String? _idFront;
  String? _idBack;
  String? _error;

  Future<void> _pickIdImage({required bool front}) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(child: Wrap(children: [
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Tomar foto'), onTap: () => Navigator.pop(sheetContext, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir de galería'), onTap: () => Navigator.pop(sheetContext, ImageSource.gallery)),
        ])),
      );
      if (source == null) return;
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 65,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 220 * 1024) {
        if (mounted) await showVitaMessage(context, 'La imagen pesa demasiado. Intenta tomarla con más luz y enfoca solo la cédula.');
        return;
      }
      setState(() {
        if (front) {
          _idFront = base64Encode(bytes);
        } else {
          _idBack = base64Encode(bytes);
        }
      });
    } catch (_) {
      if (mounted) await showVitaMessage(context, 'No se pudo abrir la cámara. Revisa los permisos de VITA.');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _document.dispose();
    _bio.dispose();
    _interests.dispose();
    _experience.dispose();
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
      presentationBio: _bio.text,
      presentationInterests: _interests.text,
      presentationExperience: _experience.text,
      presentationConsent: _presentationConsent,
      idFrontBase64: _idFront ?? '',
      idBackBase64: _idBack ?? '',
      identityDocumentConsent: _identityConsent,
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
          const SizedBox(height: 8),
          const Text('Cédula de ciudadanía (frente y reverso)', style: TextStyle(fontWeight: FontWeight.w800)),
          const Text('Las imágenes serán privadas. Solo tú y coordinación podrán verlas para validar tu identidad; nunca se mostrarán a los adultos mayores.'),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickIdImage(front: true), icon: const Icon(Icons.camera_alt_outlined), label: Text(_idFront == null ? 'Tomar frente' : 'Frente listo'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickIdImage(front: false), icon: const Icon(Icons.camera_alt_outlined), label: Text(_idBack == null ? 'Tomar reverso' : 'Reverso listo'))),
          ]),
          if (_idFront != null || _idBack != null)
            Row(children: [
              if (_idFront != null) Expanded(child: Padding(padding: const EdgeInsets.all(4), child: Image.memory(base64Decode(_idFront!), height: 100, fit: BoxFit.contain))),
              if (_idBack != null) Expanded(child: Padding(padding: const EdgeInsets.all(4), child: Image.memory(base64Decode(_idBack!), height: 100, fit: BoxFit.contain))),
            ]),
          CheckboxListTile(
            value: _identityConsent,
            onChanged: (v) => setState(() => _identityConsent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Autorizo a VITA y a coordinación a tratar estas imágenes de mi cédula exclusivamente para verificar mi identidad y decidir mi vinculación como voluntario.'),
          ),
          const Text('La cédula no se publica ni se comparte con la persona mayor. Coordinación debe revisarla para activar la cuenta.'),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          const SizedBox(height: 16),
          const Text('Perfil que podrá ver la persona mayor al encontrarlos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          TextField(controller: _bio, maxLength: 180, maxLines: 2, decoration: const InputDecoration(labelText: 'Presentación corta')),
          TextField(controller: _interests, maxLength: 160, decoration: const InputDecoration(labelText: 'Intereses')),
          TextField(controller: _experience, maxLength: 240, maxLines: 2, decoration: const InputDecoration(labelText: 'Experiencia de voluntariado')),
          CheckboxListTile(
            value: _presentationConsent,
            onChanged: (v) => setState(() => _presentationConsent = v ?? false),
            title: const Text('Autorizo de forma voluntaria que VITA publique mi nombre, foto y presentación a la persona mayor asignada, después de la revisión de coordinación. Puedo retirar esta autorización desde mi perfil.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Text('La autorización es opcional. Si no la das, no publicaremos esta presentación. La coordinación revisará el contenido antes de mostrarlo.'),
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
