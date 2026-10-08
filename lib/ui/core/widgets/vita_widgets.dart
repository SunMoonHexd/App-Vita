import 'package:flutter/material.dart';

class VitaPage extends StatelessWidget {
  const VitaPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

class VitaPrimaryButton extends StatelessWidget {
  const VitaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, textAlign: TextAlign.center);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 32),
        label: child,
      ),
    );
  }
}

class VitaErrorText extends StatelessWidget {
  const VitaErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message!,
        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 18),
      ),
    );
  }
}

Future<void> showVitaMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('App VITA'),
      content: Text(message, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
      ],
    ),
  );
}

const consentText =
    'Autorizo el tratamiento de mis datos personales conforme a la Ley 1581 de 2012 (Habeas Data). '
    'App VITA usa nombre, teléfono, fecha de nacimiento y contactos de apoyo para el servicio de acompañamiento. '
    'Las videollamadas no se graban. Puedo solicitar la eliminación de mis datos.';

const termsText =
    'El acompañamiento es social y conversacional. No sustituye atención médica, psicológica ni la línea 123. '
    'No compartas dirección, dinero, claves ni códigos. No contactes a la otra persona fuera de la app.';

const conductText =
    'Código de conducta: no pedir dinero, claves, códigos ni datos sensibles; no contactar al adulto mayor '
    'fuera de VITA; tratar con respeto; avisar a coordinación ante una emergencia.';
