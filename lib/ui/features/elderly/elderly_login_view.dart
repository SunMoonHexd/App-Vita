import 'package:flutter/material.dart';
import 'package:vita_app/data/services/biometric_access.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/elderly/elderly_recover_view.dart';

class ElderlyLoginView extends StatefulWidget {
  const ElderlyLoginView({super.key});

  @override
  State<ElderlyLoginView> createState() => _ElderlyLoginViewState();
}

class _ElderlyLoginViewState extends State<ElderlyLoginView> {
  String _phoneDigits = '';
  String _pin = '';
  String? _error;
  bool _loading = false;
  bool _enterPin = false;

  String get _formattedPhone {
    final chunks = <String>[];
    for (var start = 0; start < _phoneDigits.length; start += 3) {
      final end = start + 3 < _phoneDigits.length
          ? start + 3
          : _phoneDigits.length;
      chunks.add(_phoneDigits.substring(start, end));
    }
    if (chunks.length > 1 && chunks.last.length == 1) {
      chunks[chunks.length - 2] += chunks.removeLast();
    }
    return chunks.join(' ');
  }

  void _addPhoneDigit(String digit) {
    if (_phoneDigits.length >= 15 || _loading) return;
    setState(() {
      _phoneDigits += digit;
      _error = null;
    });
  }

  void _removePhoneDigit() {
    if (_phoneDigits.isEmpty || _loading) return;
    setState(() {
      _phoneDigits = _phoneDigits.substring(0, _phoneDigits.length - 1);
      _error = null;
    });
  }

  void _continueToPin() {
    if (_phoneDigits.length < 7) {
      setState(() => _error = 'Escribe al menos 7 números de celular.');
      return;
    }
    setState(() {
      _enterPin = true;
      _error = null;
      _pin = '';
    });
  }

  void _digit(String digit) {
    if (_pin.length >= 4 || _loading) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _backspacePin() {
    if (_pin.isEmpty || _loading) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _editPhone() {
    setState(() {
      _enterPin = false;
      _pin = '';
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_pin.length != 4 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await VitaScope.of(context)
          .loginElderly(phone: _phoneDigits, pin: _pin);
      if (!mounted) return;
      setState(() => _loading = false);
      if (!result.isOk) {
        setState(() {
          _error = result.error;
          _pin = '';
        });
        return;
      }
      BiometricAccess.markCredentialLogin(result.user!.id);
      await BiometricAccess.offerAfterLogin(context, uid: result.user!.id);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE2F5F1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        const VitaLogoHeader(),
                        const SizedBox(height: 16),
                        const Text(
                          'Inicia sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _enterPin
                              ? 'Ahora marca tu PIN de 4 números.'
                              : 'Primero, escribe tu número de celular.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.35,
                            color: VitaColors.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const VitaConnectionPill(),
                        const SizedBox(height: 22),
                        if (_enterPin) _pinStep() else _phoneStep(),
                        const SizedBox(height: 12),
                        VitaErrorText(_error),
                        const SizedBox(height: 12),
                        if (_enterPin)
                          VitaPrimaryButton(
                            label: _loading ? 'Ingresando…' : 'Ingresar',
                            icon: Icons.lock_open_rounded,
                            height: 72,
                            onPressed: _pin.length == 4 && !_loading
                                ? _submit
                                : null,
                          )
                        else
                          VitaPrimaryButton(
                            label: 'Continuar',
                            icon: Icons.arrow_forward_rounded,
                            height: 72,
                            onPressed: _phoneDigits.length >= 7
                                ? _continueToPin
                                : null,
                          ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ElderlyRecoverView(),
                            ),
                          ),
                          child: const Text(
                            'Necesito ayuda con mi PIN',
                            style: TextStyle(fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                child: _enterPin
                    ? Semantics(
                        button: true,
                        label: 'Cambiar número de celular',
                        child: IconButton.filledTonal(
                          onPressed: _editPhone,
                          icon: const Icon(Icons.arrow_back_rounded),
                          iconSize: 28,
                          tooltip: 'Cambiar número',
                        ),
                      )
                    : const VitaBackButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneStep() {
    final hasPhone = _phoneDigits.isNotEmpty;
    return Column(
      children: [
        const VitaFieldLabel('Número de celular', fontSize: 19),
        Semantics(
          liveRegion: true,
          label: hasPhone
              ? 'Número de celular: $_formattedPhone'
              : 'Número de celular vacío',
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VitaColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  size: 30,
                  color: VitaColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    hasPhone
                        ? _formattedPhone
                        : 'Toca los números para escribir',
                    style: TextStyle(
                      fontSize: hasPhone ? 24 : 17,
                      fontWeight: hasPhone ? FontWeight.w800 : FontWeight.w600,
                      color: hasPhone ? VitaColors.ink : VitaColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Usa el teclado de abajo. Puedes borrar un número si te equivocas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.3, color: VitaColors.muted),
        ),
        const SizedBox(height: 16),
        VitaKeypad(onDigit: _addPhoneDigit, onBackspace: _removePhoneDigit),
      ],
    );
  }

  Widget _pinStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: VitaColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.phone_android_rounded,
                size: 26,
                color: VitaColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formattedPhone,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _editPhone,
                child: const Text('Cambiar', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const VitaFieldLabel('PIN de 4 números', fontSize: 19),
        const SizedBox(height: 6),
        const Text(
          'Marca tus cuatro números en el teclado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, color: VitaColors.muted),
        ),
        const SizedBox(height: 10),
        VitaPinDots(length: _pin.length),
        const SizedBox(height: 18),
        VitaKeypad(onDigit: _digit, onBackspace: _backspacePin),
      ],
    );
  }
}
