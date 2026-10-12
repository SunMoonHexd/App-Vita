import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class VolunteerRecoverView extends StatefulWidget {
  const VolunteerRecoverView({super.key});

  @override
  State<VolunteerRecoverView> createState() => _VolunteerRecoverViewState();
}

class _VolunteerRecoverViewState extends State<VolunteerRecoverView> {
  final _email = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      await VitaScope.of(context).startPasswordRecovery(_email.text.trim());
      setState(() {
        _sent = true;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Recuperar contraseña',
      child: ListView(
        children: [
          const Text('Escribe tu correo y te enviaremos un enlace para crear una contraseña nueva.'),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          const SizedBox(height: 12),
          VitaPrimaryButton(label: 'Enviar enlace', onPressed: _send),
          if (_sent) ...[
            const SizedBox(height: 16),
            const Text(
              'Listo. Si el correo está registrado, te llegará un mensaje con el enlace. Revisa también la carpeta de spam.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 12),
          VitaErrorText(_error),
        ],
      ),
    );
  }
}
