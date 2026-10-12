import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _familyHint;
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp(String familyPhone, String code) async {
    var digits = familyPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '57$digits';
    final text = Uri.encodeComponent(
      'VITA: el código para restablecer el PIN de tu familiar es $code. '
      'Caduca en 15 minutos. Si no pediste esto, ignora el mensaje.',
    );
    final uri = Uri.parse('https://wa.me/$digits?text=$text');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await VitaScope.of(context).startPinRecovery(_phone.text.trim());
      await _openWhatsApp(ticket.familyPhone, ticket.code);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _familyHint = ticket.familyName;
        _loading = false;
      });
      await showVitaMessage(
        context,
        'Enviamos un código por WhatsApp a ${ticket.familyName}. '
        'Si no abre WhatsApp, el familiar puede pedirle el código a coordinación. '
        'Código de esta prueba: ${ticket.code}',
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await VitaScope.of(context).completePinRecovery(
        phone: _phone.text.trim(),
        code: _code.text.trim(),
        newPin: _pin.text.trim(),
      );
      if (!mounted) return;
      await showVitaMessage(context, 'PIN restablecido. Ya puedes ingresar.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Recuperar PIN',
      child: ListView(
        children: [
          const Text(
            'Tu familiar registrado recibirá un código por WhatsApp. '
            'Si no responde, coordinación puede restablecer el acceso tras verificar tu identidad.',
            style: TextStyle(fontSize: 18, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            enabled: !_codeSent,
            decoration: const InputDecoration(labelText: 'Tu teléfono'),
          ),
          const SizedBox(height: 12),
          VitaPrimaryButton(
            label: _loading ? 'Enviando...' : 'Pedir código al familiar',
            onPressed: _loading ? null : _send,
          ),
          if (_codeSent) ...[
            const SizedBox(height: 16),
            Text(
              _familyHint == null
                  ? 'Código enviado al familiar.'
                  : 'Código enviado a $_familyHint.',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextField(controller: _code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Código de 6 dígitos')),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              maxLength: 4,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nuevo PIN'),
            ),
            VitaPrimaryButton(label: _loading ? 'Guardando...' : 'Guardar PIN', onPressed: _loading ? null : _confirm),
          ],
          VitaErrorText(_error),
        ],
      ),
    );
  }
}
