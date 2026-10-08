import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class ElderlyRecoverView extends StatefulWidget {
  const ElderlyRecoverView({super.key});

  @override
  State<ElderlyRecoverView> createState() => _ElderlyRecoverViewState();
}

class _ElderlyRecoverViewState extends State<ElderlyRecoverView> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _pin = TextEditingController();
  String? _sentCode;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      final code = await VitaScope.of(context).startPinRecovery(_phone.text.trim());
      setState(() {
        _sentCode = code;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirm() async {
    try {
      await VitaScope.of(context).completePinRecovery(code: _code.text.trim(), newPin: _pin.text.trim());
      if (!mounted) return;
      await showVitaMessage(context, 'PIN restablecido. Ya puedes ingresar.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Recuperar PIN',
      child: ListView(
        children: [
          const Text('Enviaremos un código al familiar registrado (en este prototipo se muestra en pantalla).'),
          const SizedBox(height: 16),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Tu teléfono')),
          const SizedBox(height: 12),
          VitaPrimaryButton(label: 'Pedir código', onPressed: _send),
          if (_sentCode != null) ...[
            const SizedBox(height: 16),
            Text('Código enviado al familiar: $_sentCode', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Código')),
            const SizedBox(height: 12),
            TextField(controller: _pin, maxLength: 4, obscureText: true, decoration: const InputDecoration(labelText: 'Nuevo PIN')),
            VitaPrimaryButton(label: 'Guardar PIN', onPressed: _confirm),
          ],
          VitaErrorText(_error),
        ],
      ),
    );
  }
}
