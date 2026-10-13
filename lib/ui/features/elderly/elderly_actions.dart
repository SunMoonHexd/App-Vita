import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

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
  final verified = await confirmWithPin(
    context,
    title: 'Confirma con tu PIN',
    subtitle: 'Escribe tu PIN para eliminar tu cuenta y tus datos.',
  );
  if (!verified || !context.mounted) return;
  await VitaScope.of(context).requestAccountDeletion();
  if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
}

/// Pide el PIN en una hoja inferior. Devuelve true solo si el PIN es correcto.
Future<bool> confirmWithPin(BuildContext context, {required String title, String? subtitle}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _PinSheet(title: title, subtitle: subtitle),
  );
  return ok == true;
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';
  String? _error;
  bool _checking = false;

  void _digit(String d) {
    if (_checking || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _backspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _checking = true);
    try {
      await VitaScope.of(context).verifyPin(_pin);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _pin = '';
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: VitaColors.muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 20),
          VitaPinDots(length: _pin.length),
          const SizedBox(height: 18),
          VitaKeypad(onDigit: _digit, onBackspace: _backspace),
          const SizedBox(height: 8),
          if (_checking) const Padding(padding: EdgeInsets.only(bottom: 8), child: CircularProgressIndicator()),
          VitaErrorText(_error),
          TextButton(
            onPressed: _checking ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
