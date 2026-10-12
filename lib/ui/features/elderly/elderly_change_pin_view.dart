import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class ElderlyChangePinView extends StatefulWidget {
  const ElderlyChangePinView({super.key});

  @override
  State<ElderlyChangePinView> createState() => _ElderlyChangePinViewState();
}

class _ElderlyChangePinViewState extends State<ElderlyChangePinView> {
  static const _titles = ['Escribe tu PIN actual', 'Escribe tu PIN nuevo', 'Repite tu PIN nuevo'];

  String _pin = '';
  String _current = '';
  String _new = '';
  int _step = 0;
  String? _error;
  bool _saving = false;

  void _digit(String d) {
    if (_saving || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _advance);
    }
  }

  void _backspace() {
    if (_saving || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _advance() async {
    if (!mounted || _pin.length != 4) return;
    if (_step == 0) {
      setState(() {
        _current = _pin;
        _pin = '';
        _step = 1;
      });
      return;
    }
    if (_step == 1) {
      if (_pin == _current) {
        setState(() {
          _error = 'El PIN nuevo debe ser distinto al actual.';
          _pin = '';
        });
        return;
      }
      setState(() {
        _new = _pin;
        _pin = '';
        _step = 2;
      });
      return;
    }
    if (_pin != _new) {
      setState(() {
        _error = 'Los PIN no coinciden. Inténtalo de nuevo.';
        _pin = '';
        _new = '';
        _step = 1;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      await VitaScope.of(context).changePin(currentPin: _current, newPin: _new);
      if (!mounted) return;
      await showVitaMessage(context, 'Tu PIN fue actualizado.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _pin = '';
        _current = '';
        _new = '';
        _step = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Cambiar PIN',
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text('Paso ${_step + 1} de 3', style: const TextStyle(fontSize: 16, color: VitaColors.muted)),
            const SizedBox(height: 8),
            Text(
              _titles[_step],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 22),
            VitaPinDots(length: _pin.length),
            const SizedBox(height: 22),
            VitaKeypad(onDigit: _digit, onBackspace: _backspace),
            const SizedBox(height: 16),
            if (_saving) const Padding(padding: EdgeInsets.only(bottom: 12), child: CircularProgressIndicator()),
            VitaErrorText(_error),
          ],
        ),
      ),
    );
  }
}
