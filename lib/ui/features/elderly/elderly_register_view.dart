import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/legal_text_view.dart';

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
  bool _loading = false;
  int _step = 0;
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
      helpText: 'Elige tu fecha de nacimiento',
      confirmText: 'Aceptar',
      cancelText: 'Cancelar',
    );
    if (picked != null) setState(() => _birth = picked);
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    String? error;
    if (_step == 0) {
      if (_name.text.trim().isEmpty) {
        error = 'Escribe tu nombre y apellidos para continuar.';
      } else if (_birth == null) {
        error = 'Elige tu fecha de nacimiento para continuar.';
      } else if (_ageAt(_birth!) < 60) {
        error = 'VITA está dirigido a personas de 60 años o más.';
      } else if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 7) {
        error = 'Revisa el número de celular. Escribe al menos 7 números.';
      }
    } else if (_step == 1 &&
        (_pin.text.length != 4 || int.tryParse(_pin.text) == null)) {
      error = 'Crea un PIN usando exactamente 4 números.';
    }

    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _step++;
      _error = null;
    });
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_birth == null) {
      setState(() => _error = 'Elige tu fecha de nacimiento.');
      return;
    }
    if (!_familyAdult) {
      setState(
        () =>
            _error = 'Confirma que el familiar registrado es mayor de 18 años.',
      );
      return;
    }
    if (!_aptitude) {
      setState(
        () => _error =
            'Confirma que puedes usar la aplicación de forma autónoma.',
      );
      return;
    }
    if (!_consent) {
      setState(
        () =>
            _error = 'Lee y acepta los términos y la política para continuar.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
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
      setState(() => _loading = false);
      if (!result.isOk) {
        setState(() => _error = result.error);
        return;
      }
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      return;
    }
  }

  String get _stepTitle => switch (_step) {
    0 => 'Empecemos con tus datos',
    1 => 'Tu acceso y contactos',
    _ => 'Revisemos antes de terminar',
  };

  String get _stepDescription => switch (_step) {
    0 => 'Usaremos estos datos para crear tu perfil.',
    1 => 'Elige un PIN fácil de recordar. Los contactos son para apoyarte.',
    _ => 'Revisa la información y confirma para crear tu cuenta.',
  };

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Crear mi cuenta',
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            'Paso ${_step + 1} de 3',
            style: const TextStyle(
              color: VitaColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_step + 1) / 3,
              minHeight: 10,
              backgroundColor: VitaColors.tint,
              color: VitaColors.primary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _stepTitle,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _stepDescription,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              color: VitaColors.muted,
            ),
          ),
          const SizedBox(height: 22),
          if (_step == 0) ..._personalFields(),
          if (_step == 1) ..._accessAndContactFields(),
          if (_step == 2) ..._consentFields(),
          VitaErrorText(_error),
          const SizedBox(height: 12),
          if (_step < 2)
            VitaPrimaryButton(
              label: 'Continuar',
              icon: Icons.arrow_forward_rounded,
              height: 72,
              onPressed: _nextStep,
            )
          else
            VitaPrimaryButton(
              label: _loading ? 'Creando tu cuenta…' : 'Crear mi cuenta',
              icon: Icons.check_circle_outline_rounded,
              height: 72,
              onPressed: _loading ? null : _submit,
            ),
          if (_step > 0) ...[
            const SizedBox(height: 10),
            VitaSecondaryButton(
              label: 'Volver',
              icon: Icons.arrow_back_rounded,
              height: 64,
              onPressed: _loading ? null : _previousStep,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _personalFields() => [
    _field(
      controller: _name,
      label: 'Nombre y apellidos',
      icon: Icons.person_outline_rounded,
      textCapitalization: TextCapitalization.words,
    ),
    const SizedBox(height: 16),
    _dateButton(),
    const SizedBox(height: 16),
    _field(
      controller: _phone,
      label: 'Número de celular',
      icon: Icons.phone_android_rounded,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    ),
  ];

  List<Widget> _accessAndContactFields() => [
    _field(
      controller: _pin,
      label: 'PIN de 4 números',
      icon: Icons.lock_outline_rounded,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    ),
    const SizedBox(height: 4),
    const Text(
      'Guárdalo en un lugar seguro. Lo necesitarás para iniciar sesión.',
      style: TextStyle(fontSize: 16, height: 1.3, color: VitaColors.muted),
    ),
    const SizedBox(height: 24),
    const _SectionHeading(
      icon: Icons.support_agent_rounded,
      title: 'Persona de apoyo',
      subtitle: 'Alguien de confianza a quien podamos contactar si hace falta.',
    ),
    const SizedBox(height: 14),
    _field(
      controller: _familyName,
      label: 'Nombre del familiar',
      icon: Icons.person_outline_rounded,
      textCapitalization: TextCapitalization.words,
    ),
    const SizedBox(height: 14),
    _field(
      controller: _familyPhone,
      label: 'Celular del familiar',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    ),
    const SizedBox(height: 14),
    _field(
      controller: _altName,
      label: 'Otro contacto (opcional)',
      icon: Icons.person_add_alt_rounded,
      textCapitalization: TextCapitalization.words,
    ),
    const SizedBox(height: 14),
    _field(
      controller: _altPhone,
      label: 'Celular del otro contacto',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    ),
  ];

  List<Widget> _consentFields() => [
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VitaColors.infoBg,
        border: Border.all(color: VitaColors.infoBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué ofrece VITA?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(termsText, style: TextStyle(fontSize: 17, height: 1.4)),
        ],
      ),
    ),
    const SizedBox(height: 16),
    const LegalLinks(),
    const SizedBox(height: 12),
    _checkCard(
      value: _familyAdult,
      onChanged: (value) => setState(() => _familyAdult = value),
      text: 'Confirmo que el familiar de contacto es mayor de 18 años.',
    ),
    const SizedBox(height: 10),
    _checkCard(
      value: _aptitude,
      onChanged: (value) => setState(() => _aptitude = value),
      text: 'Puedo usar la aplicación de forma autónoma.',
    ),
    const SizedBox(height: 10),
    _checkCard(
      value: _consent,
      onChanged: (value) => setState(() => _consent = value),
      text: 'Acepto los términos de uso y la política de privacidad, y autorizo el tratamiento de mis datos personales.',
    ),
  ];

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 20),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 18),
        prefixIcon: Icon(icon, size: 27),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _dateButton() {
    final birth = _birth;
    final text = birth == null
        ? 'Seleccionar fecha de nacimiento'
        : '${birth.day}/${birth.month}/${birth.year}';
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _pickBirth,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: Colors.white,
          foregroundColor: VitaColors.ink,
          side: const BorderSide(color: VitaColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        icon: const Icon(Icons.calendar_month_rounded, size: 28),
        label: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  int _ageAt(DateTime birth) {
    final today = DateTime.now();
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age;
  }

  Widget _checkCard({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: VitaColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: _loading ? null : (next) => onChanged(next ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        checkboxScaleFactor: 1.2,
        title: Text(text, style: const TextStyle(fontSize: 17, height: 1.3)),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 30, color: VitaColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.3,
                  color: VitaColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
