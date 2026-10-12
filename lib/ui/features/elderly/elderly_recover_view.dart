import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

/// Recuperar el PIN (RF12). Sin servidor propio no se puede validar un código de forma
/// segura desde el celular, así que el restablecimiento lo hace siempre coordinación
/// después de verificar la identidad de la persona.
class ElderlyRecoverView extends StatelessWidget {
  const ElderlyRecoverView({super.key});

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Recuperar PIN',
      child: ListView(
        children: [
          const Text(
            'Por tu seguridad, el PIN lo restablece coordinación.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pídele a tu familiar o cuidador que se comunique con coordinación de VITA. '
            'Ellos verificarán que eres tú y te dejarán un PIN nuevo para que vuelvas a entrar.',
            style: TextStyle(fontSize: 18, height: 1.4),
          ),
          const SizedBox(height: 24),
          VitaPrimaryButton(label: 'Entendido', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
