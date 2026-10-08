import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Bienvenida',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: const [
                _Tip(icon: Icons.video_call, text: 'Pulsa el botón grande para hablar con un voluntario.'),
                _Tip(icon: Icons.health_and_safety, text: 'VITA no sustituye un médico, un psicólogo ni la línea 123.'),
                _Tip(
                  icon: Icons.security,
                  text: 'No compartas horarios en los que estás solo, dirección, dinero, claves ni códigos.',
                ),
                _Tip(icon: Icons.mic, text: 'Cuando inicie la llamada, acepta cámara y micrófono.'),
              ],
            ),
          ),
          VitaPrimaryButton(
            label: 'Entendido, continuar',
            onPressed: () async {
              await VitaScope.of(context).completeOnboarding();
              onDone();
            },
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
        title: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
