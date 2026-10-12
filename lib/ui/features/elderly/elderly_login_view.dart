import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/elderly/elderly_recover_view.dart';

class ElderlyLoginView extends StatefulWidget {
  const ElderlyLoginView({super.key});

  @override
  State<ElderlyLoginView> createState() => _ElderlyLoginViewState();
}

class _ElderlyLoginViewState extends State<ElderlyLoginView> {
  final _phone = TextEditingController();
  String _pin = '';
  String? _error;
  bool _loading = false;

  bool get _canSubmit =>
      !_loading && _phone.text.replaceAll(RegExp(r'\D'), '').length >= 7 && _pin.length == 4;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _digit(String d) {
    if (_pin.length >= 4 || _loading) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty || _loading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await VitaScope.of(context).loginElderly(phone: _phone.text.trim(), pin: _pin);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.isOk) {
      setState(() {
        _error = result.error;
        _pin = '';
      });
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
            colors: [Color(0xFFE2F5F1), Colors.white],
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
                      'Bienvenido a VITA',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const VitaConnectionPill(),
                    const SizedBox(height: 22),
                    const VitaFieldLabel('Tu número de celular'),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 20),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        hintText: 'Ej: 300 123 4567',
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text('📱', style: TextStyle(fontSize: 22)),
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const VitaFieldLabel('Tu PIN de 4 dígitos'),
                    const SizedBox(height: 4),
                    VitaPinDots(length: _pin.length),
                    const SizedBox(height: 18),
                    VitaKeypad(onDigit: _digit, onBackspace: _backspace),
                    const SizedBox(height: 18),
                    VitaErrorText(_error),
                    VitaPrimaryButton(
                      label: _loading ? 'Ingresando...' : 'Ingresar',
                      onPressed: _canSubmit ? _submit : null,
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ElderlyRecoverView()),
                      ),
                      child: const Text('Olvidé mi PIN'),
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
