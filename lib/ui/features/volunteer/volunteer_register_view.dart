import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
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
  bool _saving = false;
  String? _personalPhoto;
  String? _idFront;
  String? _idBack;
  String? _error;
  int _step = 0;

  static const _steps = [
    ('Tus datos', Icons.person_outline_rounded),
    ('Identidad', Icons.badge_outlined),
    ('Tu cuenta', Icons.lock_outline_rounded),
    ('Tu presentación', Icons.waving_hand_outlined),
    ('Compromisos', Icons.favorite_border_rounded),
  ];

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

  Future<void> _pickIdImage({required bool front}) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
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
        if (mounted) {
          await showVitaMessage(
            context,
            'La imagen pesa demasiado. Intenta de nuevo con más luz y enfocando solo la cédula.',
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        if (front) {
          _idFront = base64Encode(bytes);
        } else {
          _idBack = base64Encode(bytes);
        }
      });
    } catch (_) {
      if (mounted) {
        await showVitaMessage(context, 'No se pudo abrir la cámara o galería. Revisa los permisos de VITA.');
      }
    }
  }

  Future<void> _takePersonalPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 220 * 1024) {
        if (mounted) await showVitaMessage(context, 'La foto pesa demasiado. Intenta tomarla con mejor iluminación.');
        return;
      }
      if (!mounted) return;
      setState(() => _personalPhoto = base64Encode(bytes));
    } catch (_) {
      if (mounted) await showVitaMessage(context, 'No se pudo abrir la cámara frontal. Revisa los permisos de VITA.');
    }
  }

  String? _validateStep() {
    switch (_step) {
      case 0:
        if (_name.text.trim().isEmpty) return 'Escribe tu nombre y apellidos.';
        if (_birth == null) return 'Indica tu fecha de nacimiento.';
        if (_document.text.trim().isEmpty) return 'Escribe el número de tu documento.';
        if (_personalPhoto == null) return 'Tómate una foto para completar tu perfil.';
        break;
      case 1:
        if (_idFront == null || _idBack == null) return 'Carga el frente y el reverso de tu cédula.';
        if (!_identityConsent) return 'Autoriza el uso de la cédula para continuar.';
        break;
      case 2:
        if (_phone.text.trim().length < 7) return 'Escribe un número de teléfono válido.';
        if (!_email.text.contains('@')) return 'Revisa tu correo electrónico.';
        if (_password.text.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';
        break;
      case 4:
        if (!_q1 || !_q2 || !_conduct) return 'Confirma los compromisos para acompañar con seguridad.';
        if (!_consent) return 'Acepta los términos y el tratamiento de tus datos para crear la cuenta.';
        break;
    }
    return null;
  }

  Future<void> _next() async {
    final error = _validateStep();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final result = await VitaScope.of(context).registerVolunteer(
      name: _name.text,
      birthDate: _birth!,
      phone: _phone.text,
      email: _email.text,
      password: _password.text,
      documentId: _document.text,
      photoBase64: _personalPhoto!,
      consent: _consent,
      conduct: _conduct,
      inductionDone: _q1 && _q2,
      presentationBio: _bio.text,
      presentationInterests: _interests.text,
      presentationExperience: _experience.text,
      presentationConsent: _presentationConsent,
      idFrontBase64: _idFront!,
      idBackBase64: _idBack!,
      identityDocumentConsent: _identityConsent,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.isOk) {
      setState(() => _error = result.error);
      return;
    }
    await showVitaMessage(
      context,
      'Cuenta creada. Verifica tu correo; después coordinación revisará tu cédula y tu solicitud.',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final stepInfo = _steps[_step];
    return VitaPage(
      title: 'Registro voluntario',
      child: Column(
        children: [
          _progress(stepInfo.$1),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stepIntro(stepInfo.$1, stepInfo.$2),
                  const SizedBox(height: 16),
                  ..._stepFields(),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    VitaErrorText(_error),
                  ],
                ],
              ),
            ),
          ),
          if (_step == 3)
            TextButton.icon(
              onPressed: _saving ? null : () => setState(() { _step = 4; _error = null; }),
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Omitir presentación por ahora'),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => setState(() { _step--; _error = null; }),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Atrás'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: VitaPrimaryButton(
                  label: _saving
                      ? 'Creando cuenta…'
                      : (_step == _steps.length - 1 ? 'Crear cuenta' : 'Continuar'),
                  icon: _step == _steps.length - 1 ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
                  onPressed: _saving ? null : _next,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progress(String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Paso ${_step + 1} de ${_steps.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: VitaColors.primary)),
              const Spacer(),
              Text(label, style: const TextStyle(color: VitaColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: (_step + 1) / _steps.length, minHeight: 8),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            children: [
              for (var i = 0; i < _steps.length; i++)
                Icon(i < _step ? Icons.check_circle : _steps[i].$2, size: 17, color: i <= _step ? VitaColors.primary : VitaColors.muted),
            ],
          ),
        ],
      );

  Widget _stepIntro(String title, IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VitaColors.infoBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VitaColors.infoBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.white, child: Icon(icon, color: VitaColors.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    switch (_step) {
                      0 => 'Cuéntanos quién eres. Estos datos ayudan a coordinación a revisar tu solicitud.',
                      1 => 'La cédula se usa solo para verificar tu identidad y se elimina después de revisarla.',
                      2 => 'Crea tus datos de acceso. Mantén tu contraseña en privado.',
                      3 => 'Cuéntale a la persona mayor un poco sobre ti. Completar esta parte es opcional.',
                      _ => 'Revisa cómo funciona VITA y confirma los compromisos antes de crear tu cuenta.',
                    },
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  List<Widget> _stepFields() => switch (_step) {
        0 => [
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre y apellidos', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(_birth == null ? 'Fecha de nacimiento' : '${_birth!.day}/${_birth!.month}/${_birth!.year}'),
                subtitle: const Text('Debes tener 18 años o más para ser voluntario.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(context: context, initialDate: DateTime(now.year - 25), firstDate: DateTime(1950), lastDate: now);
                  if (picked != null) setState(() => _birth = picked);
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: _document, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de cédula', prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: VitaColors.border)),
              child: Column(children: [
                const Row(children: [Icon(Icons.face_retouching_natural_outlined, color: VitaColors.primary), SizedBox(width: 8), Expanded(child: Text('Tu foto personal (obligatoria)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)))]),
                const SizedBox(height: 6),
                const Text('Tómate una selfie con la cámara frontal. Debe verse claramente tu rostro y salir solo tú; no uses logos, mascotas, paisajes ni imágenes ilustradas.'),
                const SizedBox(height: 12),
                if (_personalPhoto != null)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: CircleAvatar(radius: 58, backgroundImage: MemoryImage(base64Decode(_personalPhoto!))),)
                else
                  const Padding(padding: EdgeInsets.only(bottom: 10), child: CircleAvatar(radius: 48, child: Icon(Icons.person_outline_rounded, size: 48))),
                OutlinedButton.icon(onPressed: _takePersonalPhoto, icon: Icon(_personalPhoto == null ? Icons.camera_alt_outlined : Icons.refresh_rounded), label: Text(_personalPhoto == null ? 'Tomar mi foto' : 'Volver a tomarla')),
              ]),
            ),
          ],
        1 => [
            const Text('Sube fotos nítidas, completas y con buena iluminación. Puedes tomar la foto ahora o elegirla de tu galería.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _pickIdImage(front: true), icon: Icon(_idFront == null ? Icons.camera_alt_outlined : Icons.check_circle), label: Text(_idFront == null ? 'Frente' : 'Frente listo'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => _pickIdImage(front: false), icon: Icon(_idBack == null ? Icons.camera_alt_outlined : Icons.check_circle), label: Text(_idBack == null ? 'Reverso' : 'Reverso listo'))),
            ]),
            if (_idFront != null || _idBack != null)
              Card(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
                if (_idFront != null) Expanded(child: Image.memory(base64Decode(_idFront!), height: 100, fit: BoxFit.contain)),
                if (_idBack != null) Expanded(child: Image.memory(base64Decode(_idBack!), height: 100, fit: BoxFit.contain)),
              ]))),
            CheckboxListTile(
              value: _identityConsent,
              onChanged: (v) => setState(() => _identityConsent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Autorizo a VITA y a coordinación a usar estas imágenes exclusivamente para verificar mi identidad y decidir mi vinculación.'),
            ),
            const _InfoCard(icon: Icons.lock_outline, text: 'Solo tú y coordinación podrán ver la cédula. La persona mayor no verá las imágenes. Se borran al verificarlas o después de 30 días si el trámite no se completa.'),
          ],
        2 => [
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 10),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', helperText: 'Al menos 6 caracteres', prefixIcon: Icon(Icons.lock_outline))),
          ],
        3 => [
            TextField(controller: _bio, maxLength: 180, maxLines: 2, decoration: const InputDecoration(labelText: 'Una presentación corta', hintText: 'Por ejemplo: Me gusta escuchar y conversar sobre música.', prefixIcon: Icon(Icons.chat_bubble_outline))),
            const SizedBox(height: 8),
            TextField(controller: _interests, maxLength: 160, decoration: const InputDecoration(labelText: 'Tus intereses', hintText: 'Jardinería, música, lectura…', prefixIcon: Icon(Icons.interests_outlined))),
            const SizedBox(height: 8),
            TextField(controller: _experience, maxLength: 240, maxLines: 2, decoration: const InputDecoration(labelText: 'Experiencia de voluntariado', hintText: 'Puedes contar si has acompañado a otras personas.', prefixIcon: Icon(Icons.volunteer_activism_outlined))),
            CheckboxListTile(
              value: _presentationConsent,
              onChanged: (v) => setState(() => _presentationConsent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Autorizo de forma voluntaria que VITA muestre mi nombre, foto y presentación a la persona mayor asignada, después de la revisión de coordinación.'),
            ),
            const _InfoCard(icon: Icons.visibility_outlined, text: 'Si autorizas, coordinación revisará el contenido antes de publicarlo. Puedes omitir el perfil y completarlo más tarde.'),
          ],
        _ => [
            const _InfoCard(icon: Icons.favorite_outline, text: 'VITA facilita compañía y conversación. No es atención médica, psicológica ni una línea de emergencias.'),
            CheckboxListTile(value: _q1, onChanged: (v) => setState(() => _q1 = v ?? false), title: const Text('Entiendo que el acompañamiento es social, no clínico.'), controlAffinity: ListTileControlAffinity.leading),
            CheckboxListTile(value: _q2, onChanged: (v) => setState(() => _q2 = v ?? false), title: const Text('No pediré dinero, claves ni datos sensibles.'), controlAffinity: ListTileControlAffinity.leading),
            CheckboxListTile(value: _conduct, onChanged: (v) => setState(() => _conduct = v ?? false), title: const Text('Acepto el código de conducta y trataré con respeto a cada persona.'), controlAffinity: ListTileControlAffinity.leading),
            CheckboxListTile(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('Acepto los términos de uso y la política de privacidad, y autorizo el tratamiento de mis datos personales conforme a la Ley 1581 de 2012.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const LegalLinks(),
          ],
      };
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: VitaColors.border)),
        child: Row(children: [
          Icon(icon, color: VitaColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35, color: VitaColors.slate))),
        ]),
      );
}
