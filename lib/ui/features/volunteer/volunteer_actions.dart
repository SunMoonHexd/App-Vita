import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
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

Future<void> confirmVolunteerLogout(BuildContext context) async {
  final ok = await _confirm(
    context,
    title: '¿Quieres salir?',
    message: 'Tendrás que ingresar de nuevo con tu correo y tu contraseña.',
    cancel: 'Quedarme',
    accept: 'Sí, salir',
  );
  if (!ok || !context.mounted) return;
  await VitaScope.of(context).logout();
  if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
}

Future<void> confirmVolunteerDeletion(BuildContext context) async {
  final ok = await _confirm(
    context,
    title: 'Eliminar mis datos',
    message: 'Se eliminará tu cuenta, tus turnos y tus datos personales. Esta acción no se puede deshacer.',
    cancel: 'Cancelar',
    accept: 'Sí, eliminar',
  );
  if (!ok || !context.mounted) return;
  final verified = await confirmWithPassword(
    context,
    title: 'Confirma tu contraseña',
    subtitle: 'Escríbela para eliminar tu cuenta y tus datos.',
  );
  if (!verified || !context.mounted) return;
  await VitaScope.of(context).requestAccountDeletion();
  if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
}

/// Pide la contraseña actual. Devuelve true solo si es correcta.
Future<bool> confirmWithPassword(BuildContext context, {required String title, String? subtitle}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PasswordDialog(title: title, subtitle: subtitle),
  );
  return ok == true;
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _checking = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_controller.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await VitaScope.of(context).verifyPassword(_controller.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(widget.subtitle!, style: const TextStyle(fontSize: 17, color: VitaColors.muted)),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _controller,
            obscureText: _hide,
            autofocus: true,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              suffixIcon: IconButton(
                tooltip: _hide ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: VitaColors.alert, fontSize: 16)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _checking ? null : _confirm,
          child: Text(_checking ? 'Verificando...' : 'Confirmar'),
        ),
      ],
    );
  }
}
