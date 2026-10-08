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
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _sent;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Recuperar contraseña',
      child: ListView(
        children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo')),
          const SizedBox(height: 12),
          VitaPrimaryButton(
            label: 'Enviar código',
            onPressed: () async {
              try {
                final code = await VitaScope.of(context).startPasswordRecovery(_email.text.trim());
                setState(() {
                  _sent = code;
                  _error = null;
                });
              } catch (e) {
                setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
              }
            },
          ),
          if (_sent != null) ...[
            const SizedBox(height: 12),
            Text('Código de correo (prototipo): $_sent', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Código')),
            const SizedBox(height: 12),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña')),
            const SizedBox(height: 12),
            VitaPrimaryButton(
              label: 'Guardar',
              onPressed: () async {
                try {
                  await VitaScope.of(context).completePasswordRecovery(code: _code.text.trim(), password: _password.text);
                  if (context.mounted) {
                    await showVitaMessage(context, 'Contraseña restablecida.');
                    if (context.mounted) Navigator.pop(context);
                  }
                } catch (e) {
                  setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
                }
              },
            ),
          ],
          VitaErrorText(_error),
        ],
      ),
    );
  }
}
