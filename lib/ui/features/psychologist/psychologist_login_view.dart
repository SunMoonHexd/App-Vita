import 'package:flutter/material.dart';
import 'package:vita_app/data/services/biometric_access.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

/// Ingreso del profesional de apoyo psicológico. La cuenta la crea coordinación; la contraseña
/// se elige con el correo que envía Firebase.
class PsychologistLoginView extends StatefulWidget {
  const PsychologistLoginView({super.key});

  @override
  State<PsychologistLoginView> createState() => _PsychologistLoginViewState();
}

class _PsychologistLoginViewState extends State<PsychologistLoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await VitaScope.of(context).loginPsychologist(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (!result.isOk) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }
    BiometricAccess.markCredentialLogin(result.user!.id);
    await BiometricAccess.offerAfterLogin(context, uid: result.user!.id);
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Apoyo psicológico',
      child: ListView(
        children: [
          const Text(
            'Ingreso para profesionales. Si aún no tienes cuenta, pídesela a coordinación.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          const SizedBox(height: 12),
          VitaErrorText(_error),
          VitaPrimaryButton(
            label: _busy ? 'Entrando…' : 'Entrar',
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
