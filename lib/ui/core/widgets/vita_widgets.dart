import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';

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
    final bg = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 2,
          shadowColor: bg.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: height >= 96 ? 40 : 30),
              const SizedBox(width: 12),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VitaColors.alert.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: VitaColors.alert),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(color: VitaColors.alert, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showVitaMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('App VITA', style: TextStyle(fontWeight: FontWeight.w800)),
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
