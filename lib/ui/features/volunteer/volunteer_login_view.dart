import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_recover_view.dart';

class VolunteerLoginView extends StatefulWidget {
  const VolunteerLoginView({super.key});

  @override
  State<VolunteerLoginView> createState() => _VolunteerLoginViewState();
}

class _VolunteerLoginViewState extends State<VolunteerLoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _hidePassword = true;

  bool get _canSubmit => !_loading && _email.text.contains('@') && _password.text.length >= 6;

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final message = await VitaScope.of(context).resendVerificationEmail(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    await showVitaMessage(context, message);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await VitaScope.of(context).loginVolunteer(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.isOk) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE4EDFA), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
                    const VitaLogoHeader(),
                    const SizedBox(height: 16),
                    const Text(
                      'Bienvenido, voluntario',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const VitaConnectionPill(),
                    const SizedBox(height: 22),
                    const VitaFieldLabel('Tu correo'),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: const TextStyle(fontSize: 18),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        hintText: 'ejemplo@correo.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const VitaFieldLabel('Tu contraseña'),
                    TextField(
                      controller: _password,
                      obscureText: _hidePassword,
                      style: const TextStyle(fontSize: 18),
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) {
                        if (_canSubmit) _submit();
                      },
                      decoration: InputDecoration(
                        hintText: 'Tu contraseña',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    VitaErrorText(_error),
                    VitaPrimaryButton(
                      label: _loading ? 'Ingresando...' : 'Ingresar',
                      color: VitaColors.secondary,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: VitaColors.secondary),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VolunteerRecoverView()),
                      ),
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: VitaColors.secondary),
                      onPressed: _canSubmit ? _resend : null,
                      child: const Text('Reenviar correo de verificación'),
                    ),
                  ],
                ),
              ),
              const Positioned(top: 8, left: 12, child: VitaBackButton()),
            ],
          ),
        ),
      ),
    );
  }
}
