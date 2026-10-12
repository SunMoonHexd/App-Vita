import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String cancel,
  required String accept,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(accept)),
      ],
    ),
  );
  return ok == true;
}

/// Pregunta antes de cerrar la sesión y vuelve a la pantalla de inicio.
Future<void> confirmLogout(BuildContext context) async {
  final ok = await _confirm(
    context,
    title: '¿Quieres salir?',
    message: 'Tendrás que ingresar de nuevo con tu celular y tu PIN.',
    cancel: 'Quedarme',
    accept: 'Sí, salir',
  );
  if (!ok || !context.mounted) return;
  await VitaScope.of(context).logout();
  if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
}

/// Pide confirmación para eliminar la cuenta y los datos personales.
Future<void> confirmDeletion(BuildContext context) async {
  final ok = await _confirm(
    context,
    title: 'Eliminar mis datos',
    message: 'Se eliminará tu cuenta y tus datos personales. Esta acción no se puede deshacer.',
    cancel: 'Cancelar',
    accept: 'Sí, eliminar',
  );
  if (!ok || !context.mounted) return;
  await VitaScope.of(context).requestAccountDeletion();
  if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
}
